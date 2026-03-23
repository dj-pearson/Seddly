import UIKit
import SwiftData
import UniformTypeIdentifiers
import Vision

class ShareViewController: UIViewController {
    private let processingLabel = UILabel()
    private let statusLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        processSharedItems()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()

        processingLabel.text = "Processing screenshot..."
        processingLabel.font = .preferredFont(forTextStyle: .headline)

        statusLabel.text = ""
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center

        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(processingLabel)
        stack.addArrangedSubview(statusLabel)

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),
        ])
    }

    private func processSharedItems() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            completeRequest()
            return
        }

        Task {
            var processed = 0

            for item in extensionItems {
                guard let attachments = item.attachments else { continue }

                for attachment in attachments {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                        let success = await processImageAttachment(attachment)
                        if success { processed += 1 }
                    }
                }
            }

            await MainActor.run {
                if processed > 0 {
                    processingLabel.text = "Added to Seddly"
                    statusLabel.text = "\(processed) screenshot\(processed == 1 ? "" : "s") queued for analysis."
                } else {
                    processingLabel.text = "No commitments found"
                    statusLabel.text = "This screenshot didn't contain detectable text."
                }
            }

            try? await Task.sleep(for: .seconds(1.5))
            completeRequest()
        }
    }

    private func processImageAttachment(_ attachment: NSItemProvider) async -> Bool {
        guard let item = try? await attachment.loadItem(
            forTypeIdentifier: UTType.image.identifier,
            options: nil
        ) else { return false }

        let image: UIImage?

        if let url = item as? URL {
            image = UIImage(contentsOfFile: url.path)
        } else if let data = item as? Data {
            image = UIImage(data: data)
        } else if let img = item as? UIImage {
            image = img
        } else {
            return false
        }

        guard let image, let cgImage = image.cgImage else { return false }

        // Run OCR on-device
        let ocrText = await performOCR(on: cgImage)
        guard let ocrText, !ocrText.isEmpty else { return false }

        // Save to shared SwiftData container
        do {
            let container = try SharedModelContainer.create()
            let context = ModelContext(container)

            let queueItem = ProcessingQueue(screenshotAssetID: "share-\(UUID().uuidString)")
            queueItem.extractedText = ocrText
            queueItem.processingStatus = .pending
            context.insert(queueItem)
            try context.save()
            return true
        } catch {
            return false
        }
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
