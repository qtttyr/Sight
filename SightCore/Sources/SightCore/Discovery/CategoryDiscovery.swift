import Foundation
import NaturalLanguage

/// A proposal to create one new folder (and the rule behind it) for a group
/// of files that fit no existing category but clearly belong together.
public struct FolderSuggestion: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let prompt: String
    /// How alike the members are, 0…1 (average pairwise similarity).
    public let coherence: Float
    public let decisions: [RoutingDecision]
    /// Why this folder was proposed, for diagnostics and the UI tooltip.
    public let evidence: String

    public var count: Int { decisions.count }
}

/// Finds folders the user is missing, without ever creating clutter.
///
/// The guard rails are the point of this type:
/// - only files that fit **no** current rule are considered;
/// - a group needs a minimum size (default 5) and real internal agreement,
///   so one odd file never gets a folder of its own;
/// - a group must be nameable with a real topic or a keyword shared by most
///   members; anonymous clusters are dropped;
/// - at most two suggestions at a time, never beyond a total rule cap, and
///   names the user already declined are not offered again.
public struct ClusterSettings: Sendable {
    public var minimumSize = 5
    /// Average similarity at which two groups may merge (batch-centered).
    public var textLink: Float = 0.30
    public var imageLink: Float = 0.45
    /// Minimum average pairwise similarity inside a finished group.
    public var textCoherence: Float = 0.34
    public var imageCoherence: Float = 0.5
    public var maximumSuggestions = 2
    public var maximumRules = 16
    /// How close the best topic must be to name the group with it.
    public var topicFloor: Float = 0.12
    public var topicGap: Float = 0.015
    /// The topic must explain the group better than any existing rule by
    /// this much, so a group that already has a home is never pulled out.
    public var topicOverRule: Float = 0.03

    public init() {}
}

enum ClusterMath {
    /// Average-linkage agglomerative clustering over unit vectors.
    static func cluster(_ vectors: [[Float]], link: Float) -> [[Int]] {
        var groups: [[Int]] = vectors.indices.map { [$0] }
        guard vectors.count > 1 else { return groups }

        var similarity = Array(repeating: Array(repeating: Float(0), count: vectors.count), count: vectors.count)
        for i in vectors.indices {
            for j in vectors.indices where j > i {
                let value = VectorMath.cosine(vectors[i], vectors[j])
                similarity[i][j] = value
                similarity[j][i] = value
            }
        }

        func average(_ a: [Int], _ b: [Int]) -> Float {
            var total: Float = 0
            for i in a { for j in b { total += similarity[i][j] } }
            return total / Float(a.count * b.count)
        }

        while groups.count > 1 {
            var best: (Float, Int, Int) = (-.infinity, 0, 0)
            for i in groups.indices {
                for j in groups.indices where j > i {
                    let value = average(groups[i], groups[j])
                    if value > best.0 { best = (value, i, j) }
                }
            }
            guard best.0 >= link else { break }
            groups[best.1] += groups[best.2]
            groups.remove(at: best.2)
        }
        return groups
    }

    static func coherence(of members: [Int], in vectors: [[Float]]) -> Float {
        guard members.count > 1 else { return 0 }
        var total: Float = 0
        var pairs: Float = 0
        for (offset, i) in members.enumerated() {
            for j in members[(offset + 1)...] {
                total += VectorMath.cosine(vectors[i], vectors[j])
                pairs += 1
            }
        }
        return total / pairs
    }

    static func centroid(of members: [Int], in vectors: [[Float]]) -> [Float] {
        VectorMath.mean(members.map { vectors[$0] })
    }
}

enum KeywordNamer {
    private static let stopwords: Set<String> = [
        "the", "and", "for", "with", "this", "that", "from", "your", "have", "will", "are", "was",
        "file", "files", "copy", "final", "new", "untitled", "document", "image", "photo",
        "это", "для", "как", "что", "или", "его", "при", "над", "под", "без"
    ]

    /// A word that appears in most members' names or openings, if any.
    static func sharedKeyword(for texts: [String]) -> String? {
        guard texts.count >= 3 else { return nil }
        var frequency: [String: Int] = [:]
        for text in texts {
            let words = Set(
                text.lowercased()
                    .split(whereSeparator: { !$0.isLetter })
                    .map(String.init)
                    .filter { $0.count >= 4 && !stopwords.contains($0) }
            )
            for word in words { frequency[word, default: 0] += 1 }
        }
        guard let best = frequency.max(by: { $0.value < $1.value }),
              Double(best.value) / Double(texts.count) >= 0.6
        else { return nil }
        return best.key.prefix(1).uppercased() + best.key.dropFirst()
    }

    static func isRussian(_ texts: [String]) -> Bool {
        let sample = texts.joined(separator: " ").prefix(2_000)
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(sample))
        return recognizer.dominantLanguage == .russian
    }
}
