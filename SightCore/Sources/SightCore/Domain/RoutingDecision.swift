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

public struct RoutingDecision: Identifiable, Sendable {
    public let id: UUID
    public let file: FileSnapshot
    public let rule: CategoryRule?
    public let score: Float
    public let runnerUp: Float
    public let accepted: Bool
    public let ranking: [(ruleID: UUID, name: String, score: Float)]

    public init(
        id: UUID = UUID(),
        file: FileSnapshot,
        rule: CategoryRule?,
        score: Float,
        runnerUp: Float,
        accepted: Bool,
        ranking: [(ruleID: UUID, name: String, score: Float)]
    ) {
        self.id = id
        self.file = file
        self.rule = rule
        self.score = score
        self.runnerUp = runnerUp
        self.accepted = accepted
        self.ranking = ranking
    }

    public var outcome: SortEvent.Outcome {
        if rule == nil { return .unrecognized }
        return accepted ? .moved : .review
    }
}
