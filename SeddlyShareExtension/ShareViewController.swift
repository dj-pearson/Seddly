import UIKit
import SwiftData
import UniformTypeIdentifiers
import Vision

class ShareViewController: UIViewController {
    private var extractedText: String?
    private var detectedSummary: String?

    private let containerStack = UIStackView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let buttonStack = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedItems()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        containerStack.axis = .vertical
        containerStack.spacing = 16
        containerStack.alignment = .center
        containerStack.translatesAutoresizingMaskIntoConstraints = false

        spinner.startAnimating()

        titleLabel.text = "Processing screenshot..."
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textAlignment = .center

        summaryLabel.text = ""
        summaryLabel.font = .preferredFont(forTextStyle: .subheadline)
        summaryLabel.textColor = .secondaryLabel
        summaryLabel.numberOfLines = 0
        summaryLabel.textAlignment = .center

        containerStack.addArrangedSubview(spinner)
        containerStack.addArrangedSubview(titleLabel)
        containerStack.addArrangedSubview(summaryLabel)

        view.addSubview(containerStack)
        NSLayoutConstraint.activate([
            containerStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            containerStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
    }

    private func processSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        Task {
            for item in extensionItems {
                guard let attachments = item.attachments else { continue }

                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        let (text, summary) = await processImageAttachment(attachment)
                        if let text {
                            extractedText = text
                            detectedSummary = summary
                            await MainActor.run { showConfirmUI(text: text, summary: summary) }
                            return // Wait for user action
                        }
                    }
                }
            }

            await MainActor.run {
                titleLabel.text = "No commitments found"
                summaryLabel.text = "This screenshot didn't contain detectable text."
                spinner.stopAnimating()
            }

            try? await Task.sleep(for: .seconds(1.5))
            completeRequest()
        }
    }

    private func showConfirmUI(text: String, summary: String?) {
        spinner.stopAnimating()
        spinner.isHidden = true

        if let summary {
            titleLabel.text = "Commitment found:"
            summaryLabel.text = summary
        } else {
            titleLabel.text = "Text extracted"
            summaryLabel.text = String(text.prefix(200))
        }

        // Create buttons
        buttonStack.axis = .horizontal
        buttonStack.spacing = 12
        buttonStack.distribution = .fillEqually
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        let confirmButton = UIButton(type: .system)
        confirmButton.setTitle("Add to Ledger", for: .normal)
        confirmButton.backgroundColor = .systemBlue
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = .boldSystemFont(ofSize: 15)
        confirmButton.layer.cornerRadius = 10
        confirmButton.addTarget(self, action: #selector(confirmTapped), for: .touchUpInside)

        let skipButton = UIButton(type: .system)
        skipButton.setTitle("Skip", for: .normal)
        skipButton.backgroundColor = .secondarySystemBackground
        skipButton.setTitleColor(.label, for: .normal)
        skipButton.titleLabel?.font = .systemFont(ofSize: 15)
        skipButton.layer.cornerRadius = 10
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        buttonStack.addArrangedSubview(skipButton)
        buttonStack.addArrangedSubview(confirmButton)

        containerStack.addArrangedSubview(buttonStack)

        NSLayoutConstraint.activate([
            buttonStack.widthAnchor.constraint(equalTo: containerStack.widthAnchor),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            skipButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func confirmTapped() {
        saveToQueue()

        titleLabel.text = "Added to Seddly"
        summaryLabel.text = "Open Seddly to review."
        buttonStack.isHidden = true

        Task {
            try? await Task.sleep(for: .seconds(1))
            completeRequest()
        }
    }

    @objc private func skipTapped() {
        completeRequest()
    }

    private func saveToQueue() {
        guard let text = extractedText else { return }

        do {
            let container = try SharedModelContainer.create()
            let context = ModelContext(container)

            let queueItem = ProcessingQueue(screenshotAssetID: "share-\(UUID().uuidString)")
            queueItem.extractedText = text
            queueItem.processingStatus = .pending
            context.insert(queueItem)
            try context.save()
        } catch {
            // Silently fail — the screenshot will be picked up on next app launch
        }
    }

    private func processImageAttachment(_ attachment: NSItemProvider) async -> (String?, String?) {
        guard let item = try? await attachment.loadItem(
            forTypeIdentifier: UTType.image.identifier,
            options: nil
        ) else { return (nil, nil) }

        let image: UIImage?

        if let url = item as? URL {
            image = UIImage(contentsOfFile: url.path)
        } else if let data = item as? Data {
            image = UIImage(data: data)
        } else if let img = item as? UIImage {
            image = img
        } else {
            return (nil, nil)
        }

        guard let image, let cgImage = image.cgImage else { return (nil, nil) }

        guard let ocrText = await performOCR(on: cgImage), !ocrText.isEmpty else {
            return (nil, nil)
        }

        // Quick rule-based check for a summary
        let score = RuleFilterService.score(text: ocrText)
        let summary = score >= AppConstants.defaultConfidenceThreshold
            ? String(ocrText.prefix(200))
            : nil

        return (ocrText, summary)
    }

    private func performOCR(on cgImage: CGImage) async -> String? {
        await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
