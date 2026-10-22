import Foundation

public struct SortEvent: Identifiable, Codable, Hashable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case moved
        case review
        case unrecognized
        case skipped
        case failed
        case undone
    }

    public let id: UUID
    public let date: Date
    public let fileName: String
    public let category: String?
    public let score: Float?
    public let outcome: Outcome
    public let message: String?

    public init(
        id: UUID = UUID(),
        date: Date = .now,
        fileName: String,
        category: String? = nil,
        score: Float? = nil,
        outcome: Outcome,
        message: String? = nil
    ) {
        self.id = id
        self.date = date
        self.fileName = fileName
        self.category = category
        self.score = score
        self.outcome = outcome
        self.message = message
    }
}

/// What Sight decided about one file.
///
/// `score` is the probability (0…1) that the winning rule is right. It is
/// calibrated across rules, so 0.9 really means "very sure" and 0.4 means
/// "a guess worth checking". `accepted` says whether that probability clears
/// the bar for moving the file without asking.
public struct RoutingDecision: Identifiable, Sendable {
    public let id: UUID
    public let file: FileSnapshot
    public let rule: CategoryRule?
    public let score: Float
    public let runnerUp: Float
    public let accepted: Bool
    public let ranking: [(ruleID: UUID, name: String, score: Float)]
    /// Same scale as `score`; kept as a separate name for call sites that
    /// talk about "how confident" rather than "how likely".
    public let confidence: Float
    /// One human sentence explaining the decision ("Video file (.mp4)").
    public let reason: String?
    /// A better file name, when the current one says nothing. The extension
    /// is included. `nil` keeps the original name.
    public let suggestedName: String?
    /// Probability mass the classifier left on "none of these rules".
    public let noneProbability: Float

    public init(
        id: UUID = UUID(),
        file: FileSnapshot,
        rule: CategoryRule?,
        score: Float,
        runnerUp: Float,
        accepted: Bool,
        ranking: [(ruleID: UUID, name: String, score: Float)],
        confidence: Float? = nil,
        reason: String? = nil,
        suggestedName: String? = nil,
        noneProbability: Float = 0
    ) {
        self.suggestedName = suggestedName
        self.noneProbability = noneProbability
        self.id = id
        self.file = file
        self.rule = rule
        self.score = score
        self.runnerUp = runnerUp
        self.accepted = accepted
        self.ranking = ranking
        self.confidence = confidence ?? score
        self.reason = reason
    }

    public var outcome: SortEvent.Outcome {
        if rule == nil { return .unrecognized }
        return accepted ? .moved : .review
    }

    /// Returns the same decision pointed at another rule, as when the user
    /// corrects a proposal in Review. The correction is, by definition,
    /// something the user stands behind.
    public func corrected(to newRule: CategoryRule) -> RoutingDecision {
        RoutingDecision(
            id: id,
            file: file,
            rule: newRule,
            score: 1,
            runnerUp: score,
            accepted: true,
            ranking: ranking,
            confidence: 1,
            reason: "Chosen by you",
            suggestedName: suggestedName,
            noneProbability: 0
        )
    }

    public func with(suggestedName name: String?) -> RoutingDecision {
        RoutingDecision(
            id: id, file: file, rule: rule, score: score, runnerUp: runnerUp,
            accepted: accepted, ranking: ranking, confidence: confidence,
            reason: reason, suggestedName: name, noneProbability: noneProbability
        )
    }
}
