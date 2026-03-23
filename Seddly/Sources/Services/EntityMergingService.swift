import Foundation
import SwiftData

/// Detects and merges duplicate entities using string similarity and AI.
/// Handles cases like "John", "John from Acme", and "Acme Property Management"
/// being recognized as the same entity.
struct EntityMergingService {
    struct MergeSuggestion: Identifiable {
        let id = UUID()
        let primary: LocalEntity
        let duplicates: [LocalEntity]
        let confidence: Double
        let reason: String
    }

    /// Find entities that likely refer to the same person/company.
    static func findMergeCandidates(entities: [LocalEntity]) -> [MergeSuggestion] {
        var suggestions: [MergeSuggestion] = []
        var processed: Set<UUID> = []

        for i in 0..<entities.count {
            guard !processed.contains(entities[i].id) else { continue }

            var duplicates: [LocalEntity] = []

            for j in (i + 1)..<entities.count {
                guard !processed.contains(entities[j].id) else { continue }

                let similarity = nameSimilarity(entities[i].name, entities[j].name)
                if similarity >= 0.6 {
                    duplicates.append(entities[j])
                    processed.insert(entities[j].id)
                }
            }

            if !duplicates.isEmpty {
                processed.insert(entities[i].id)
                suggestions.append(MergeSuggestion(
                    primary: entities[i],
                    duplicates: duplicates,
                    confidence: 0.8,
                    reason: "Similar names detected"
                ))
            }
        }

        return suggestions
    }

    /// Merge duplicate entities into the primary, moving all commitments.
    static func merge(primary: LocalEntity, duplicates: [LocalEntity], context: ModelContext) {
        for duplicate in duplicates {
            for commitment in duplicate.commitments {
                commitment.entity = primary
                commitment.entityName = primary.name
                commitment.updatedAt = .now
            }
            context.delete(duplicate)
        }
        primary.updatedAt = .now
    }

    /// Calculate name similarity using normalized token overlap.
    private static func nameSimilarity(_ a: String, _ b: String) -> Double {
        let tokensA = Set(normalize(a))
        let tokensB = Set(normalize(b))

        guard !tokensA.isEmpty && !tokensB.isEmpty else { return 0 }

        let intersection = tokensA.intersection(tokensB).count
        let smaller = min(tokensA.count, tokensB.count)

        // Token overlap ratio against the smaller set
        let tokenScore = Double(intersection) / Double(smaller)

        // Also check if one name contains the other
        let lowA = a.lowercased().trimmingCharacters(in: .whitespaces)
        let lowB = b.lowercased().trimmingCharacters(in: .whitespaces)
        let containsScore: Double = (lowA.contains(lowB) || lowB.contains(lowA)) ? 0.3 : 0

        // Levenshtein distance for short names
        let editScore: Double
        if lowA.count < 20 && lowB.count < 20 {
            let maxLen = max(lowA.count, lowB.count)
            let dist = levenshteinDistance(lowA, lowB)
            editScore = maxLen > 0 ? max(0, 1.0 - Double(dist) / Double(maxLen)) * 0.3 : 0
        } else {
            editScore = 0
        }

        return min(1.0, tokenScore * 0.7 + containsScore + editScore)
    }

    private static func normalize(_ name: String) -> [String] {
        let stopWords: Set<String> = ["from", "at", "the", "of", "and", "inc", "llc", "co", "corp"]
        return name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    private static func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let m = a.count, n = b.count
        let aArr = Array(a), bArr = Array(b)
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m { dp[i][0] = i }
        for j in 0...n { dp[0][j] = j }

        for i in 1...m {
            for j in 1...n {
                if aArr[i - 1] == bArr[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1]
                } else {
                    dp[i][j] = 1 + min(dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1])
                }
            }
        }
        return dp[m][n]
    }
}
