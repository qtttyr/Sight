import Foundation

/// Decides which rule a file belongs to.
///
/// Three independent kinds of evidence are combined into one calibrated
/// probability per rule:
///
/// 1. **Type evidence** (`TypeProfile`): extension, name conventions, image
///    metadata. Near-certain where it applies and free to compute.
/// 2. **Semantic evidence**: the file's content is embedded and compared with
///    every *idea* in each rule's description, not one blurred average.
/// 3. **Learned evidence**: files the user already confirmed pull similar
///    files toward the same category.
///
/// The evidence is added in log-odds space and passed through a softmax that
/// also contains a "none of these" option, so the winner's probability means
/// what it says.
public actor ClassificationService {
    /// Every calibrated constant of the classifier, in one place.
    public struct Tuning: Sendable, Equatable {
        /// Sharpness of text similarity (smaller = more decisive).
        public var textTemperature: Float = 0.03
        public var imageTemperature: Float = 0.04
        /// How many of a rule's best-matching ideas are averaged.
        public var poolTop: Int = 2
        /// Log-odds added for certain (strength 1.0) type evidence.
        public var typeBoost: Float = 6
        /// Log-odds added when a learned example is a near duplicate.
        public var exampleBoost: Float = 5
        /// Centered similarity at which examples start to count / saturate.
        public var exampleFloor: Float = 0.35
        public var exampleCeiling: Float = 0.8
        /// Similarity a rule must beat to be better than "none of these".
        public var textNoneSimilarity: Float = 0.12
        public var imageNoneSimilarity: Float = 0.06
        /// Share of the vision encoder when a name hint is also available.
        public var visionWeight: Float = 0.6

        public init() {}
    }

    private struct RuleVectors: Sendable {
        let signature: String
        let anchors: [String]
        /// Anchor embeddings for text-vs-text comparison.
        let textAnchors: [[Float]]
        /// Anchor embeddings in the search-query space, for text-vs-image.
        let imageAnchors: [[Float]]
        let centroid: [Float]
    }

    private struct Evidence {
        var similarity: Float
        var bestAnchor: String?
    }

    /// Where the time of a classification went. Performance work needs
    /// numbers, not guesses.
    public struct Timings: Sendable {
        /// The text tower.
        public var textEmbed: TimeInterval = 0
        /// The vision tower.
        public var imageEmbed: TimeInterval = 0
        /// Comparing the file against every rule.
        public var compare: TimeInterval = 0
        /// Looking at the examples the user confirmed.
        public var learned: TimeInterval = 0
    }

    public var tuning = Tuning()

    private let provider: any EmbeddingProviding
    private let examples: ExampleStore?
    private var cache: [UUID: RuleVectors] = [:]
    private var textMean: [Float] = []
    private var imageMean: [Float] = []

    /// Timings of the last classification, for the profiler.
    public private(set) var timings = Timings()

    /// The plain vectors of the file that was classified last. The caller
    /// can reuse them instead of embedding the very same file a second time.
    public private(set) var lastVectors: (text: [Float]?, image: [Float]?) = (nil, nil)

    public init(provider: any EmbeddingProviding, examples: ExampleStore? = nil) {
        self.provider = provider
        self.examples = examples
    }

    public func setTuning(_ tuning: Tuning) {
        self.tuning = tuning
    }

    // MARK: - Preparing rules

    public func prepare(rules: [CategoryRule]) async throws {
        let validRules = rules.filter(\.isValid)
        let validIDs = Set(validRules.map(\.id))
        cache = cache.filter { validIDs.contains($0.key) }
        examples?.retain(ruleIDs: Set(rules.map(\.id)))

        for rule in validRules {
            if let existing = cache[rule.id], existing.signature == rule.semanticSignature {
                continue
            }
            let anchors = rule.anchors
            var textAnchors: [[Float]] = []
            var imageAnchors: [[Float]] = []
            for anchor in anchors {
                textAnchors.append(VectorMath.normalize(try await provider.embed(text: anchor, kind: .classification)))
                if let image = try? await provider.embed(text: anchor, kind: .searchQuery) {
                    imageAnchors.append(VectorMath.normalize(image))
                }
            }
            cache[rule.id] = RuleVectors(
                signature: rule.semanticSignature,
                anchors: anchors,
                textAnchors: textAnchors,
                imageAnchors: imageAnchors,
                centroid: VectorMath.mean(textAnchors)
            )
        }

        textMean = VectorMath.mean(cache.values.flatMap(\.textAnchors))
        imageMean = VectorMath.mean(cache.values.flatMap(\.imageAnchors))
    }

    public func fingerprint(for rule: CategoryRule, dimension: Int) -> [Float] {
        guard let vectors = cache[rule.id] else { return [] }
        return VectorMath.fingerprint(VectorMath.prefix(vectors.centroid, dimension: dimension))
    }

    // MARK: - Classifying

    public func classify(
        context: FileContext,
        rules: [CategoryRule],
        dimension: Int,
        confidence: Float = SightConfig.defaultConfidence
    ) async throws -> RoutingDecision {
        timings = Timings()
        let validRules = rules.filter { $0.isValid && cache[$0.id] != nil }
        guard !validRules.isEmpty else {
            return empty(for: context.file)
        }

        let dim = min(dimension, provider.dimension)
        let profile = context.profile

        // Rules the file's type rules out are not considered at all, unless
        // that would leave nothing to choose from.
        var candidates = validRules.filter { rule in
            guard let kind = rule.kind else { return true }
            return !profile.excludes.contains(kind)
        }
        if candidates.isEmpty { candidates = validRules }

        let observation = try await observe(context: context, dimension: dim)

        var logits: [Float] = []
        var reasons: [UUID: String] = [:]
        for rule in candidates {
            var logit: Float = 0
            var reason: String?

            if let text = observation.text(for: rule.id) {
                logit += (text.similarity - tuning.textNoneSimilarity) / tuning.textTemperature
                if let anchor = text.bestAnchor { reason = "Matches “\(anchor)”" }
            }
            if let image = observation.image(for: rule.id) {
                let blendedWeight = observation.hasText ? tuning.visionWeight : 1
                // Vision can say "this looks less like X" but not veto strong
                // type evidence, so its negative side is floored.
                let own = max((image.similarity - tuning.imageNoneSimilarity) / tuning.imageTemperature, -1.5)
                logit = observation.hasText ? (1 - blendedWeight) * logit + blendedWeight * own : own
                if reason == nil || own > 0, let anchor = image.bestAnchor, blendedWeight >= 0.5 {
                    reason = "Looks like “\(anchor)”"
                }
            }

            var typeLift: Float = 0
            if let kind = rule.kind, let strength = profile.boosts[kind] {
                typeLift = strength * tuning.typeBoost
                logit += typeLift
                if strength >= 0.5 { reason = profile.reasons[kind] }
            }

            let learned = learnedBoost(for: rule.id, observation: observation, dimension: dim)
            if learned.boost > 0 {
                logit += learned.boost * tuning.exampleBoost
                if learned.boost >= 0.5 { reason = "Similar to files you sorted here before" }
            }

            logits.append(logit)
            if let reason { reasons[rule.id] = reason }
        }

        // "None of these" sits at logit 0: a rule is only likely when its
        // evidence adds up to more than the baseline.
        let probabilities = VectorMath.softmax(logits + [0])
        var ranking: [(ruleID: UUID, name: String, score: Float)] = candidates.enumerated().map {
            ($1.id, $1.name, probabilities[$0])
        }
        ranking.sort { $0.score > $1.score }

        guard let best = ranking.first, let rule = candidates.first(where: { $0.id == best.ruleID }) else {
            return empty(for: context.file)
        }
        let runnerUp = ranking.dropFirst().first?.score ?? 0
        let required = max(confidence, rule.threshold ?? 0)

        return RoutingDecision(
            file: context.file,
            rule: rule,
            score: best.score,
            runnerUp: runnerUp,
            accepted: best.score >= required,
            ranking: ranking,
            reason: reasons[rule.id],
            noneProbability: probabilities.last ?? 0
        )
    }

    // MARK: - Evidence

    private struct Observation {
        var textQuery: [Float]?
        var imageQuery: [Float]?
        var textEvidence: [UUID: Evidence] = [:]
        var imageEvidence: [UUID: Evidence] = [:]

        var hasText: Bool { textQuery != nil && !textEvidence.isEmpty }
        func text(for id: UUID) -> Evidence? { textEvidence[id] }
        func image(for id: UUID) -> Evidence? { imageEvidence[id] }
    }

    private func observe(context: FileContext, dimension: Int) async throws -> Observation {
        var observation = Observation()
        var rawText: [Float]?
        var rawImage: [Float]?
        let cleanText = (context.text ?? context.hint)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let cleanText, !cleanText.isEmpty {
            let started = ContinuousClock.now
            let embedded = try await provider.embed(text: cleanText, kind: .classification)
            timings.textEmbed += (ContinuousClock.now - started).seconds
            rawText = VectorMath.normalize(embedded)
            let query = VectorMath.prefix(rawText!, dimension: dimension)
            observation.textQuery = query
            let mean = VectorMath.prefix(textMean, dimension: dimension)
            let centered = VectorMath.normalize(VectorMath.centered(query, removing: mean))
            let comparing = ContinuousClock.now
            for (id, vectors) in cache {
                observation.textEvidence[id] = pooled(
                    query: centered,
                    anchors: vectors.textAnchors,
                    names: vectors.anchors,
                    mean: mean,
                    centerQuery: true,
                    dimension: dimension
                )
            }
            timings.compare += (ContinuousClock.now - comparing).seconds
        }

        if let imageURL = context.imageURL {
            let started = ContinuousClock.now
            let embedded = try await provider.embed(imageAt: imageURL)
            timings.imageEmbed += (ContinuousClock.now - started).seconds
            rawImage = VectorMath.normalize(embedded)
            let query = VectorMath.prefix(rawImage!, dimension: dimension)
            observation.imageQuery = query
            let mean = VectorMath.prefix(imageMean, dimension: dimension)
            let comparing = ContinuousClock.now
            for (id, vectors) in cache where !vectors.imageAnchors.isEmpty {
                // Image and text vectors live in different regions of the
                // space, so only the anchors are centered: the query's
                // offset is the same for every rule and cancels out.
                observation.imageEvidence[id] = pooled(
                    query: query,
                    anchors: vectors.imageAnchors,
                    names: vectors.anchors,
                    mean: mean,
                    centerQuery: false,
                    dimension: dimension
                )
            }
            timings.compare += (ContinuousClock.now - comparing).seconds
        }
        lastVectors = (rawText, rawImage)
        return observation
    }

    private func pooled(
        query: [Float],
        anchors: [[Float]],
        names: [String],
        mean: [Float],
        centerQuery: Bool,
        dimension: Int
    ) -> Evidence {
        var sims: [Float] = []
        var best: (Float, Int) = (-.infinity, 0)
        for (index, anchor) in anchors.enumerated() {
            let reference = VectorMath.prefix(anchor, dimension: dimension)
            let centered = VectorMath.normalize(VectorMath.centered(reference, removing: mean))
            let value = VectorMath.cosine(query, centered)
            sims.append(value)
            if value > best.0 { best = (value, index) }
        }
        let name = best.1 < names.count ? names[best.1] : nil
        return Evidence(similarity: VectorMath.topMean(sims, count: tuning.poolTop), bestAnchor: name)
    }

    /// 0…1: how strongly the user's earlier confirmations point at this rule.
    private func learnedBoost(for ruleID: UUID, observation: Observation, dimension: Int) -> (boost: Float, count: Int)
    {
        guard let examples else { return (0, 0) }
        let started = ContinuousClock.now
        defer { timings.learned += (ContinuousClock.now - started).seconds }
        var strongest: Float = 0
        var used = 0
        for (isImage, query) in [(false, observation.textQuery), (true, observation.imageQuery)] {
            guard let query, let vectors = examples.vectors(isImage: isImage)[ruleID], !vectors.isEmpty else {
                continue
            }
            let mean = VectorMath.prefix(isImage ? imageMean : textMean, dimension: dimension)
            let centeredQuery = VectorMath.normalize(VectorMath.centered(query, removing: mean))
            let sims = vectors.map { vector -> Float in
                let reference = VectorMath.prefix(vector, dimension: dimension)
                return VectorMath.cosine(
                    centeredQuery, VectorMath.normalize(VectorMath.centered(reference, removing: mean)))
            }
            let top = VectorMath.topMean(sims, count: 2)
            let span = max(tuning.exampleCeiling - tuning.exampleFloor, 0.01)
            let boost = min(max((top - tuning.exampleFloor) / span, 0), 1)
            strongest = max(strongest, boost)
            used += vectors.count
        }
        return (strongest, used)
    }

    // MARK: - Topics (naming new folders)

    private struct TopicVectors {
        let topic: Topic
        let text: [[Float]]
        let image: [[Float]]
    }

    private var topics: [TopicVectors] = []
    private var topicTextMean: [Float] = []
    private var topicImageMean: [Float] = []

    private func prepareTopics() async {
        guard topics.isEmpty else { return }
        var built: [TopicVectors] = []
        for topic in TopicCatalog.all {
            var text: [[Float]] = []
            var image: [[Float]] = []
            for anchor in topic.anchors {
                if let vector = try? await provider.embed(text: anchor, kind: .classification) {
                    text.append(VectorMath.normalize(vector))
                }
                if let vector = try? await provider.embed(text: anchor, kind: .searchQuery) {
                    image.append(VectorMath.normalize(vector))
                }
            }
            built.append(TopicVectors(topic: topic, text: text, image: image))
        }
        topics = built
        topicTextMean = VectorMath.mean(built.flatMap(\.text))
        topicImageMean = VectorMath.mean(built.flatMap(\.image))
    }

    public struct TopicVerdict: Sendable {
        public let topic: Topic
        public let topicSimilarity: Float
        /// How well the best *existing rule* explains the same group.
        public let ruleSimilarity: Float
        /// Lead of the best topic over the second best.
        public let runnerUpGap: Float
    }

    /// Asks: is this group of files explained better by an everyday topic
    /// than by any of the user's rules? Rules and topics are compared in one
    /// shared space so their scores are directly comparable.
    public func explain(centroid: [Float], isImage: Bool) async -> TopicVerdict? {
        await prepareTopics()
        let ruleAnchors = cache.values.flatMap { isImage ? $0.imageAnchors : $0.textAnchors }
        let topicAnchors = topics.flatMap { isImage ? $0.image : $0.text }
        let mean = VectorMath.mean(ruleAnchors + topicAnchors)
        guard !mean.isEmpty else { return nil }
        let query =
            isImage
            ? VectorMath.normalize(centroid)
            : VectorMath.normalize(VectorMath.centered(centroid, removing: mean))

        func score(_ anchors: [[Float]]) -> Float? {
            guard !anchors.isEmpty else { return nil }
            let sims = anchors.map {
                VectorMath.cosine(query, VectorMath.normalize(VectorMath.centered($0, removing: mean)))
            }
            return VectorMath.topMean(sims, count: tuning.poolTop)
        }

        var scored: [(Topic, Float)] = []
        for entry in topics {
            if let value = score(isImage ? entry.image : entry.text) { scored.append((entry.topic, value)) }
        }
        scored.sort { $0.1 > $1.1 }
        guard let best = scored.first else { return nil }
        let ruleBest = cache.values.compactMap { score(isImage ? $0.imageAnchors : $0.textAnchors) }.max() ?? -1
        return TopicVerdict(
            topic: best.0,
            topicSimilarity: best.1,
            ruleSimilarity: ruleBest,
            runnerUpGap: best.1 - (scored.dropFirst().first?.1 ?? -1)
        )
    }

    // MARK: - Learning

    /// The embedding of a file, in the form the example store keeps.
    public func exampleVector(for context: FileContext) async -> (vector: [Float], isImage: Bool)? {
        if let imageURL = context.imageURL {
            guard let raw = try? await provider.embed(imageAt: imageURL) else { return nil }
            return (VectorMath.normalize(raw), true)
        }
        guard let text = context.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty,
            let raw = try? await provider.embed(text: text, kind: .classification)
        else { return nil }
        return (VectorMath.normalize(raw), false)
    }

    private func empty(for file: FileSnapshot) -> RoutingDecision {
        RoutingDecision(file: file, rule: nil, score: 0, runnerUp: 0, accepted: false, ranking: [])
    }
}
