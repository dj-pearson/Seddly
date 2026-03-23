import UIKit
import SwiftData
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        processSharedItems()
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
                        await processImageAttachment(attachment)
                    }
                }
            }
            completeRequest()
        }
    }

    private func processImageAttachment(_ attachment: NSItemProvider) async {
        guard let item = try? await attachment.loadItem(
            forTypeIdentifier: UTType.image.identifier,
            options: nil
        ) else { return }

        let image: UIImage?

        if let url = item as? URL {
            image = UIImage(contentsOfFile: url.path)
        } else if let data = item as? Data {
            image = UIImage(data: data)
        } else if let img = item as? UIImage {
            image = img
        } else {
            return
        }

        guard image != nil else { return }

        // Queue for processing — the main app will pick this up
        do {
            let container = try SharedModelContainer.create()
            let context = ModelContext(container)

            let queueItem = ProcessingQueue(screenshotAssetID: "share-\(UUID().uuidString)")
            context.insert(queueItem)
            try context.save()
        } catch {
            // Silently fail — the screenshot will be picked up on next app launch
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
