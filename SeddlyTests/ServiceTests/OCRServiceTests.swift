import Testing
import Foundation
import UIKit
@testable import Seddly

@Suite("OCRService Tests")
struct OCRServiceTests {
    @Test("recognizeText extracts text from image with rendered text")
    func extractTextFromImage() async throws {
        let service = OCRService()

        // Create an image with rendered text
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 100))
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: CGSize(width: 400, height: 100))
            UIColor.white.setFill()
            ctx.fill(rect)
            let text = "We will deliver the project by Friday" as NSString
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.black,
            ]
            text.draw(in: CGRect(x: 10, y: 30, width: 380, height: 60), withAttributes: attributes)
        }

        let result = try await service.recognizeText(in: image)
        // Vision should extract the rendered text
        #expect(!result.isEmpty)
        // The text should contain key words from our rendered text
        let lowercased = result.lowercased()
        #expect(lowercased.contains("deliver") || lowercased.contains("project") || lowercased.contains("friday"))
    }

    @Test("recognizeText returns empty string for blank image")
    func emptyImageReturnsEmptyText() async throws {
        let service = OCRService()

        // Create a solid white image with no text
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: 100, height: 100)))
        }

        let result = try await service.recognizeText(in: image)
        #expect(result.isEmpty)
    }

    @Test("OCRError.invalidImage has descriptive message")
    func invalidImageErrorDescription() {
        let error = OCRService.OCRError.invalidImage
        #expect(error.errorDescription != nil)
        #expect(error.errorDescription!.contains("image"))
    }

    @Test("recognizeText handles image with multiple lines")
    func multiLineTextExtraction() async throws {
        let service = OCRService()

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 200))
        let image = renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: CGSize(width: 500, height: 200))
            UIColor.white.setFill()
            ctx.fill(rect)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: UIColor.black,
            ]
            ("Line one of text" as NSString).draw(
                in: CGRect(x: 10, y: 20, width: 480, height: 40),
                withAttributes: attributes
            )
            ("Line two of text" as NSString).draw(
                in: CGRect(x: 10, y: 80, width: 480, height: 40),
                withAttributes: attributes
            )
        }

        let result = try await service.recognizeText(in: image)
        #expect(!result.isEmpty)
        // Should have content from both lines
        let lowercased = result.lowercased()
        #expect(lowercased.contains("line") || lowercased.contains("text"))
    }
}
