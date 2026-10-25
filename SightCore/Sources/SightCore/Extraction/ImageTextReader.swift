import Foundation
import ImageIO
import Vision

/// One recognised line of text and how prominent it is on the page.
public struct OCRLine: Sendable {
    public let text: String
    /// Relative height of the line (0…1): headings are tall.
    public let height: Double
    public let confidence: Float
}

/// Reads text from an image with Apple's on-device Vision OCR. Used only to
/// understand and name files, so it works on a downscaled copy for speed.
public enum ImageTextReader {
    public static func lines(of url: URL, maxPixels: Int = 1_280) -> [OCRLine] {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return [] }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return [] }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "ru-RU"]
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard (try? handler.perform([request])) != nil, let observations = request.results else { return [] }

        var result: [OCRLine] = []
        for observation in observations {
            guard let candidate = observation.topCandidates(1).first else { continue }
            // The status bar and home indicator are never content.
            guard observation.boundingBox.midY < 0.95, observation.boundingBox.midY > 0.04 else { continue }
            result.append(
                OCRLine(
                    text: candidate.string.trimmingCharacters(in: .whitespacesAndNewlines),
                    height: Double(observation.boundingBox.height),
                    confidence: candidate.confidence
                ))
        }
        return result.sorted { $0.height > $1.height }
    }
}
