import SwiftUI
import SwiftData

struct EntityMergeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalEntity.name) private var entities: [LocalEntity]
    @State private var suggestions: [EntityMergingService.MergeSuggestion] = []
    @State private var hasScanned = false

    var body: some View {
        List {
            if !hasScanned {
                Section {
                    Button {
                        suggestions = EntityMergingService.findMergeCandidates(entities: entities)
                        hasScanned = true
                    } label: {
                        Label("Scan for Duplicates", systemImage: "person.2.circle")
                    }
                }
            } else if suggestions.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("No duplicate entities found.")
                    }
                }
            } else {
                ForEach(suggestions) { suggestion in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Keep: \(suggestion.primary.name)")
                                .fontWeight(.semibold)

                            ForEach(suggestion.duplicates, id: \.id) { dup in
                                HStack {
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("Merge: \(dup.name) (\(dup.totalCommitments) commitments)")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text(suggestion.reason)
                                .font(.caption)
                                .foregroundStyle(.tertiary)

                            HStack {
                                Button {
                                    EntityMergingService.merge(
                                        primary: suggestion.primary,
                                        duplicates: suggestion.duplicates,
                                        context: modelContext
                                    )
                                    suggestions.removeAll { $0.id == suggestion.id }
                                } label: {
                                    Label("Merge", systemImage: "arrow.triangle.merge")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)

                                Button {
                                    suggestions.removeAll { $0.id == suggestion.id }
                                } label: {
                                    Text("Skip")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Merge Entities")
        .navigationBarTitleDisplayMode(.inline)
    }
}
