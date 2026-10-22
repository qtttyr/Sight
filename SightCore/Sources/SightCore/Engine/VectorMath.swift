import Accelerate
import Foundation

public enum VectorMath {
    public static func normalize(_ vector: [Float]) -> [Float] {
        var result = vector
        var norm: Float = 0
        vDSP_svesq(vector, 1, &norm, vDSP_Length(vector.count))
        norm = sqrt(norm)
        guard norm > 0 else { return vector }
        var divisor = norm
        vDSP_vsdiv(vector, 1, &divisor, &result, 1, vDSP_Length(vector.count))
        return result
    }

    public static func cosine(_ lhs: [Float], _ rhs: [Float]) -> Float {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot: Float = 0
        vDSP_dotpr(lhs, 1, rhs, 1, &dot, vDSP_Length(lhs.count))
        return dot
    }

    public static func prefix(_ vector: [Float], dimension: Int) -> [Float] {
        guard dimension > 0, dimension < vector.count else { return vector }
        return normalize(Array(vector.prefix(dimension)))
    }

    /// Removes a shared direction from a vector.
    ///
    /// Embedding models place every text near a common "generic document"
    /// direction, so raw cosine similarities between unrelated texts land
    /// around 0.7 and the differences between candidate rules collapse into
    /// the third decimal. Subtracting the mean direction of the rule set
    /// removes that shared component and leaves the part that actually
    /// distinguishes one rule from another.
    public static func centered(_ vector: [Float], removing mean: [Float]) -> [Float] {
        guard !mean.isEmpty, vector.count == mean.count else { return vector }
        var result = vector
        var negated = mean
        vDSP_vneg(negated, 1, &negated, 1, vDSP_Length(mean.count))
        vDSP_vadd(vector, 1, negated, 1, &result, 1, vDSP_Length(vector.count))
        return result
    }

    public static func mean(_ vectors: [[Float]]) -> [Float] {
        guard let first = vectors.first else { return [] }
        var sum = [Float](repeating: 0, count: first.count)
        for vector in vectors where vector.count == first.count {
            vDSP_vadd(sum, 1, vector, 1, &sum, 1, vDSP_Length(first.count))
        }
        var count = Float(vectors.count)
        vDSP_vsdiv(sum, 1, &count, &sum, 1, vDSP_Length(first.count))
        return normalize(sum)
    }

    /// Mean of the `count` largest values. Rewards a rule for matching a few
    /// of its ideas well without letting one lucky phrase decide.
    public static func topMean(_ values: [Float], count: Int) -> Float {
        guard !values.isEmpty else { return 0 }
        let take = max(1, min(count, values.count))
        let top = values.sorted(by: >).prefix(take)
        return top.reduce(0, +) / Float(take)
    }

    /// Numerically stable softmax.
    public static func softmax(_ logits: [Float]) -> [Float] {
        guard let peak = logits.max() else { return [] }
        let exps = logits.map { Float(exp(Double($0 - peak))) }
        let total = exps.reduce(0, +)
        guard total > 0 else { return logits.map { _ in 1 / Float(logits.count) } }
        return exps.map { $0 / total }
    }

    /// A compact, deterministic visual fingerprint of a vector. The UI uses
    /// this to render a real 32-bar signature for each category.
    public static func fingerprint(_ vector: [Float], bins: Int = 32) -> [Float] {
        guard !vector.isEmpty, bins > 0 else { return [] }
        let size = max(1, vector.count / bins)
        return (0..<bins).map { bin in
            let start = bin * size
            let end = min(vector.count, start + size)
            guard start < end else { return 0 }
            var sum: Float = 0
            for index in start..<end { sum += abs(vector[index]) }
            return sum / Float(end - start)
        }
    }
}
