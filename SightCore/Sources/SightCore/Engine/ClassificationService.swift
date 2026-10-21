import Foundation

/// Caches the semantic vectors for category prompts and performs zero-shot
/// routing. The actor owns the only mutable cache in the classification path.
public actor ClassificationService {
    private struct RuleVectors: Sendable {
        let signature: String
        let text: [Float]
        let image: [Float]?
    }

    private let provider: any EmbeddingProviding
    private var cache: [UUID: RuleVectors] = [:]

    public init(provider: any EmbeddingProviding) {
        self.provider = provider
    }

    public func prepare(rules: [CategoryRule]) async throws {
        let validRules = rules.filter(\.isValid)
        let validIDs = Set(validRules.map(\.id))
        cache = cache.filter { validIDs.contains($0.key) }

        for rule in validRules {
            if let existing = cache[rule.id], existing.signature == rule.semanticSignature {
                continue
            }
            let text = try await provider.embed(text: rule.prompt, kind: .classification)
            let image = try? await provider.embed(text: rule.prompt, kind: .searchQuery)
            cache[rule.id] = RuleVectors(
                signature: rule.semanticSignature,
                text: VectorMath.normalize(text),
                image: image.map(VectorMath.normalize)
            )
        }
    }

    public func classify(
        context: FileContext,
        rules: [CategoryRule],
        threshold: Float,
        margin: Float,
        dimension: Int
    ) async throws -> RoutingDecision {
        let validRules = rules.filter(\.isValid)
        guard !validRules.isEmpty else {
            return decision(for: context.file, rule: nil, score: 0, runnerUp: 0, accepted: false, ranking: [])
        }

        let isImage = context.imageURL != nil
        let effectiveDimension = min(dimension, provider.dimension)
        let query: [Float]
        if let imageURL = context.imageURL {
            query = try await provider.embed(imageAt: imageURL)
        } else if let text = context.text {
            query = try await provider.embed(text: text, kind: .classification)
        } else {
            return decision(for: context.file, rule: nil, score: 0, runnerUp: 0, accepted: false, ranking: [])
        }

        let normalizedQuery = VectorMath.prefix(VectorMath.normalize(query), dimension: effectiveDimension)
        var ranking: [(ruleID: UUID, name: String, score: Float)] = []

        for rule in validRules {
            guard let vectors = cache[rule.id] else { continue }
            let reference: [Float]?
            if isImage {
                reference = vectors.image
            } else {
                reference = vectors.text
            }
            guard let reference, reference.count >= effectiveDimension else { continue }
            let truncated = VectorMath.prefix(reference, dimension: effectiveDimension)
            let score = VectorMath.cosine(normalizedQuery, truncated)
            ranking.append((rule.id, rule.name, score))
        }

        ranking.sort { $0.score > $1.score }
        guard let best = ranking.first else {
            return decision(for: context.file, rule: nil, score: 0, runnerUp: 0, accepted: false, ranking: [])
        }

        let runnerUp = ranking.dropFirst().first?.score ?? 0
        let rule = validRules.first { $0.id == best.ruleID }
        let requiredThreshold = rule?.threshold ?? threshold
        let accepted = best.score >= requiredThreshold && (best.score - runnerUp) >= margin

        return decision(
            for: context.file,
            rule: rule,
            score: best.score,
            runnerUp: runnerUp,
            accepted: accepted,
            ranking: ranking
        )
    }

    public func fingerprint(for rule: CategoryRule, dimension: Int) -> [Float] {
        guard let vectors = cache[rule.id] else { return [] }
        let truncated = VectorMath.prefix(vectors.text, dimension: dimension)
        return VectorMath.fingerprint(truncated)
    }

    private func decision(
        for file: FileSnapshot,
        rule: CategoryRule?,
        score: Float,
        runnerUp: Float,
        accepted: Bool,
        ranking: [(ruleID: UUID, name: String, score: Float)]
    ) -> RoutingDecision {
        RoutingDecision(
            file: file,
            rule: rule,
            score: score,
            runnerUp: runnerUp,
            accepted: accepted,
            ranking: ranking
        )
    }
}
