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
