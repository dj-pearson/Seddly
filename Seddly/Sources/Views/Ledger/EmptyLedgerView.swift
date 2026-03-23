import SwiftUI

struct EmptyLedgerView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Commitments Yet", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Take a screenshot of a promise someone made, or add one manually.")
        } actions: {
            Button("Add Manually") {
                // Handled by parent view
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    EmptyLedgerView()
}
