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
    private var editContainer: UIStackView?
    private var entityField: UITextField?
    private var summaryField: UITextField?

    /// Maximum image dimension (pixels) to process — downscale larger images to stay within extension memory budget (~120 MB).
    private static let maxImageDimension: CGFloat = 2048
    /// Maximum number of images to process concurrently in a single share session.
    private static let maxConcurrentImages = 2

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
            let result: (String?, String?)? = await withTaskGroup(of: (String?, String?)?.self) { group in
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    var processed = 0
                    for item in extensionItems {
                        guard let attachments = item.attachments else { continue }
                        for attachment in attachments {
                            guard processed < Self.maxConcurrentImages else { return nil }
                            if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                                let result = await self.processImageAttachment(attachment)
                                processed += 1
                                if result.0 != nil { return result }
                            }
                        }
                    }
                    return nil
                }

                // 10-second timeout task
                group.addTask {
                    try? await Task.sleep(for: .seconds(10))
                    return nil
                }

                // Return whichever finishes first
                for await value in group {
                    if let value {
                        group.cancelAll()
                        return value
                    }
                }
                group.cancelAll()
                return nil
            }

            if let result, let text = result.0 {
                extractedText = text
                detectedSummary = result.1
                await MainActor.run { showConfirmUI(text: text, summary: result.1) }
                return
            }

            // Either no text found or timed out
            await MainActor.run {
                if Task.isCancelled {
                    titleLabel.text = "Processing timed out"
                    summaryLabel.text = "The screenshot took too long to process. Try again from the app."
                } else {
                    titleLabel.text = "No commitments found"
                    summaryLabel.text = "This screenshot didn't contain detectable text."
                }
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

        let editButton = UIButton(type: .system)
        editButton.setTitle("Edit", for: .normal)
        editButton.backgroundColor = .systemOrange.withAlphaComponent(0.15)
        editButton.setTitleColor(.systemOrange, for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        editButton.layer.cornerRadius = 10
        editButton.addTarget(self, action: #selector(editTapped), for: .touchUpInside)

        let skipButton = UIButton(type: .system)
        skipButton.setTitle("Skip", for: .normal)
        skipButton.backgroundColor = .secondarySystemBackground
        skipButton.setTitleColor(.label, for: .normal)
        skipButton.titleLabel?.font = .systemFont(ofSize: 15)
        skipButton.layer.cornerRadius = 10
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)

        buttonStack.addArrangedSubview(skipButton)
        buttonStack.addArrangedSubview(editButton)
        buttonStack.addArrangedSubview(confirmButton)

        containerStack.addArrangedSubview(buttonStack)

        NSLayoutConstraint.activate([
            buttonStack.widthAnchor.constraint(equalTo: containerStack.widthAnchor),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            skipButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    @objc private func confirmTapped() {
        let success = saveToQueue()

        if success {
            titleLabel.text = "Added to Seddly"
            summaryLabel.text = "Open Seddly to review."
        } else {
            titleLabel.text = "Save failed"
            summaryLabel.text = "Couldn't save right now. Open Seddly — it will pick this up automatically."
        }
        buttonStack.isHidden = true

        Task {
            try? await Task.sleep(for: .seconds(1))
            completeRequest()
        }
    }

    @objc private func editTapped() {
        buttonStack.isHidden = true

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let entityTextField = UITextField()
        entityTextField.placeholder = "Entity name (e.g. Landlord, Acme Corp)"
        entityTextField.borderStyle = .roundedRect
        entityTextField.text = "Unknown"
        self.entityField = entityTextField

        let summaryTextField = UITextField()
        summaryTextField.placeholder = "Summary of the commitment"
        summaryTextField.borderStyle = .roundedRect
        summaryTextField.text = detectedSummary ?? String((extractedText ?? "").prefix(200))
        self.summaryField = summaryTextField

        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save to Ledger", for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .boldSystemFont(ofSize: 15)
        saveButton.layer.cornerRadius = 10
        saveButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        saveButton.addTarget(self, action: #selector(saveEditTapped), for: .touchUpInside)

        stack.addArrangedSubview(entityTextField)
        stack.addArrangedSubview(summaryTextField)
        stack.addArrangedSubview(saveButton)

        containerStack.addArrangedSubview(stack)
        editContainer = stack
    }

    @objc private func saveEditTapped() {
        detectedSummary = summaryField?.text ?? detectedSummary
        let success = saveToQueue(entityName: entityField?.text)

        if success {
            titleLabel.text = "Added to Seddly"
            summaryLabel.text = "Open Seddly to review."
        } else {
            titleLabel.text = "Save failed"
            summaryLabel.text = "Couldn't save right now. Open Seddly — it will pick this up automatically."
        }
        editContainer?.isHidden = true

        Task {
            try? await Task.sleep(for: .seconds(1))
            completeRequest()
        }
    }

    @objc private func skipTapped() {
        completeRequest()
    }

    /// Saves the extracted text to the processing queue and returns whether the save succeeded.
    @discardableResult
    private func saveToQueue(entityName: String? = nil) -> Bool {
        guard let text = extractedText else { return false }

        do {
            let container = try SharedModelContainer.create()
            let context = ModelContext(container)

            let shareID = "share-\(UUID().uuidString)"
            let score = RuleFilterService.score(text: text)

            // Save to processing queue for tracking
            let queueItem = ProcessingQueue(screenshotAssetID: shareID)
            queueItem.extractedText = text
            queueItem.ruleBasedScore = score
            queueItem.processingStatus = .completed
            context.insert(queueItem)

            // If rule filter passes threshold, create a commitment directly
            if score >= AppConstants.defaultConfidenceThreshold {
                let sanitizedEntity = (entityName ?? "Unknown").trimmingCharacters(in: .whitespacesAndNewlines)
                let sanitizedSummary = (detectedSummary ?? String(text.prefix(200))).trimmingCharacters(in: .whitespacesAndNewlines)
                let commitment = LocalCommitment(
                    entityName: sanitizedEntity.isEmpty ? "Unknown" : sanitizedEntity,
                    summary: sanitizedSummary.isEmpty ? String(text.prefix(200)) : sanitizedSummary,
                    fullText: text,
                    source: .shareSheet,
                    screenshotAssetID: shareID,
                    screenshotDate: .now,
                    needsAIProcessing: true
                )
                context.insert(commitment)
            }

            try context.save()

            // Clear any pending retry since we succeeded
            UserDefaults(suiteName: SharedConstants.appGroupIdentifier)?.removeObject(forKey: "pendingShareRetry")

            return true
        } catch {
            // Queue for retry on next app launch
            let retryData: [String: String] = [
                "text": text,
                "summary": detectedSummary ?? "",
                "entityName": entityName ?? "",
                "shareID": "share-\(UUID().uuidString)",
            ]
            if let data = try? JSONEncoder().encode(retryData) {
                UserDefaults(suiteName: SharedConstants.appGroupIdentifier)?.set(data, forKey: "pendingShareRetry")
            }
            return false
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

        guard let image else { return (nil, nil) }

        // Downscale if image exceeds memory-safe dimensions
        let safeImage = downsampleIfNeeded(image)
        guard let cgImage = safeImage.cgImage else { return (nil, nil) }

        guard let ocrText = await performOCR(on: cgImage), !ocrText.isEmpty else {
            return (nil, nil)
        }

        // Quick rule-based check for a summary — called once, reused below
        let score = RuleFilterService.score(text: ocrText)
        let summary = score >= AppConstants.defaultConfidenceThreshold
            ? String(ocrText.prefix(200))
            : nil

        return (ocrText, summary)
    }

    /// Downscales the image if either dimension exceeds `maxImageDimension` to keep memory usage within the extension's budget.
    private func downsampleIfNeeded(_ image: UIImage) -> UIImage {
        let maxDim = Self.maxImageDimension
        let width = image.size.width
        let height = image.size.height

        guard width > maxDim || height > maxDim else { return image }

        let scale = min(maxDim / width, maxDim / height)
        let newSize = CGSize(width: width * scale, height: height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
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
