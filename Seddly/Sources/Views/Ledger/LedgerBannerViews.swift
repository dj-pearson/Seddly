import SwiftUI

// MARK: - US-153 — Extracted banner views
//
// These are self-contained presentations previously inlined as computed
// properties inside LedgerView. Extracting them shrinks LedgerView, gives
// each banner a SwiftUI #Preview, and surfaces their real dependencies as
// explicit parameters.

struct LedgerOfflineBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.white)
            Text("Offline")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
            Text("— AI extraction and sync require internet")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.orange)
        .clipShape(Capsule())
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct LedgerProcessingBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.white)
            Text("Processing new screenshots...")
                .font(.caption)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.accent)
        .clipShape(Capsule())
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct LedgerUndoToast: View {
    let label: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(.white)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
            Button("Undo", action: onUndo)
                .font(.subheadline.bold())
                .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.accentColor.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview("Offline") {
    LedgerOfflineBanner().padding()
}

#Preview("Processing") {
    LedgerProcessingBanner().padding()
}

#Preview("Undo") {
    LedgerUndoToast(label: "Fulfilled \"Send invoice\"", onUndo: {})
        .padding()
}
