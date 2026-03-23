import SwiftUI

struct EmptyLedgerView: View {
    var onAddManually: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("No Commitments Yet", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Take a screenshot of a promise someone made, or add one manually.")
        } actions: {
            if let onAddManually {
                Button("Add Manually", action: onAddManually)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    EmptyLedgerView()
}
