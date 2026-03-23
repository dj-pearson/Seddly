import SwiftUI
import SwiftData
import Photos

struct AICoachView: View {
    @Environment(\.modelContext) private var modelContext
    var onComplete: () -> Void

    @State private var currentStep = 0
    @State private var screenshots: [PHAsset] = []
    @State private var processedResults: [CoachResult] = []
    @State private var isProcessing = false
    @State private var currentImage: UIImage?

    struct CoachResult: Identifiable {
        let id = UUID()
        let image: UIImage
        let ocrText: String
        let ruleScore: Int
        let classification: String
        let commitmentFound: Bool
        let explanation: String
    }

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            ProgressView(value: Double(currentStep), total: 4)
                .padding(.horizontal)
                .padding(.top)

            ScrollView {
                VStack(spacing: 24) {
                    switch currentStep {
                    case 0: introStep
                    case 1: processingStep
                    case 2: resultsStep
                    case 3: completeStep
                    default: EmptyView()
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Steps

    private var introStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.accent)

            Text("Let's See Seddly in Action")
                .font(.title2.bold())

            Text("We'll grab a few of your recent screenshots and show you exactly how Seddly analyzes them — step by step.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                CoachBullet(number: 1, text: "We read the text from your screenshot (on-device)")
                CoachBullet(number: 2, text: "We classify what type of screenshot it is")
                CoachBullet(number: 3, text: "We scan for commitment language (promises, deadlines, amounts)")
                CoachBullet(number: 4, text: "You see exactly what we found and why")
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                startProcessing()
            } label: {
                Text("Let's Go")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Skip") { onComplete() }
                .foregroundStyle(.secondary)
        }
    }

    private var processingStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            if let image = currentImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 4)
            }

            if isProcessing {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.3)
                    Text("Analyzing screenshot \(processedResults.count + 1) of \(min(screenshots.count, 3))...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        CoachStatusRow(icon: "text.viewfinder", label: "Reading text (OCR)", done: true)
                        CoachStatusRow(icon: "tag", label: "Classifying screenshot type", done: processedResults.count > 0 || currentImage != nil)
                        CoachStatusRow(icon: "magnifyingglass", label: "Scanning for commitments", done: false)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Show results as they come in
            ForEach(processedResults) { result in
                CoachResultCard(result: result)
            }
        }
    }

    private var resultsStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green)

            Text("Analysis Complete")
                .font(.title2.bold())

            let found = processedResults.filter(\.commitmentFound).count
            if found > 0 {
                Text("Seddly found \(found) potential commitment\(found == 1 ? "" : "s") in your screenshots!")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Text("No commitments detected in these screenshots — that's normal! Seddly works best with text conversations, emails, and receipts.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }

            ForEach(processedResults) { result in
                CoachResultCard(result: result)
            }

            Text("This is exactly what happens every time you take a screenshot — Seddly handles it automatically.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.tertiary)

            Button {
                currentStep = 3
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var completeStep: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            Image(systemName: "hand.thumbsup.fill")
                .font(.system(size: 60))
                .foregroundStyle(.accent)

            Text("You're All Set")
                .font(.title2.bold())

            Text("Seddly will now watch for commitments in your screenshots. You can always add commitments manually, edit anything Seddly detects, or adjust settings anytime.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.accent)
                    Text("Tap + to add commitments manually")
                        .font(.subheadline)
                }
                HStack(spacing: 12) {
                    Image(systemName: "hand.draw.fill").foregroundStyle(.accent)
                    Text("Swipe right to mark fulfilled, left to dismiss")
                        .font(.subheadline)
                }
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up.fill").foregroundStyle(.accent)
                    Text("Share screenshots directly to Seddly from any app")
                        .font(.subheadline)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                onComplete()
            } label: {
                Text("Open Ledger")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Processing

    private func startProcessing() {
        currentStep = 1
        isProcessing = true

        Task {
            let service = ScreenshotService()
            let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: .now)
            screenshots = await service.fetchNewScreenshots(since: cutoff)

            let ocrService = OCRService()
            let classifierService = ClassifierService()
            let limit = min(screenshots.count, 3)

            for i in 0..<limit {
                let asset = screenshots[i]
                guard let image = await loadImage(from: asset) else { continue }

                await MainActor.run { currentImage = image }

                // Slight delay so user can see each step
                try? await Task.sleep(for: .milliseconds(800))

                let ocrText = (try? await ocrService.recognizeText(in: image)) ?? ""
                let category = await classifierService.classify(image, ocrText: ocrText)
                let ruleScore = RuleFilterService.score(text: ocrText)

                let commitmentFound = category.shouldProcess && ruleScore >= AppConstants.defaultConfidenceThreshold

                let explanation: String
                if ocrText.isEmpty {
                    explanation = "No readable text found in this screenshot."
                } else if !category.shouldProcess {
                    explanation = "This looks like a \(category.rawValue) screenshot — not the type that typically contains commitments. Skipped."
                } else if ruleScore < AppConstants.defaultConfidenceThreshold {
                    explanation = "Text was found but the commitment language score (\(ruleScore)/100) is below the threshold (\(AppConstants.defaultConfidenceThreshold)). No strong promises, deadlines, or amounts detected."
                } else {
                    explanation = "Commitment language detected! Score: \(ruleScore)/100. This screenshot contains promise indicators and would be queued for AI extraction."
                }

                let result = CoachResult(
                    image: image,
                    ocrText: String(ocrText.prefix(200)),
                    ruleScore: ruleScore,
                    classification: category.rawValue,
                    commitmentFound: commitmentFound,
                    explanation: explanation
                )

                await MainActor.run {
                    processedResults.append(result)
                }

                try? await Task.sleep(for: .milliseconds(500))
            }

            await MainActor.run {
                isProcessing = false
                currentStep = 2
            }
        }
    }

    private func loadImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 600, height: 600),
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

// MARK: - Subviews

private struct CoachBullet: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.accent)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct CoachStatusRow: View {
    let icon: String
    let label: String
    let done: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : icon)
                .foregroundStyle(done ? .green : .secondary)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(done ? .primary : .secondary)
        }
    }
}

private struct CoachResultCard: View {
    let result: AICoachView.CoachResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(uiImage: result.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(result.classification.capitalized)
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())

                        Text("Score: \(result.ruleScore)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Image(systemName: result.commitmentFound ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundStyle(result.commitmentFound ? .green : .secondary)
                            .font(.caption)
                        Text(result.commitmentFound ? "Commitment detected" : "No commitment")
                            .font(.caption)
                            .foregroundStyle(result.commitmentFound ? .primary : .secondary)
                    }
                }

                Spacer()
            }

            Text(result.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !result.ocrText.isEmpty {
                DisclosureGroup("Extracted text") {
                    Text(result.ocrText)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
