import Darwin
import Foundation
import ImageIO

/// Cheap, decode-free facts about an image: how big it is and where it came
/// from. They separate a camera photo from a screen capture far more reliably
/// than any embedding, and cost microseconds to read.
public struct ImageFacts: Sendable, Equatable {
    public var pixelWidth: Int
    public var pixelHeight: Int
    /// Make/model or exposure data written by a real camera.
    public var hasCameraMetadata: Bool
    public var hasGPS: Bool
    /// macOS flags its own screenshots with an extended attribute.
    public var isScreenCapture: Bool
    /// When the camera took the picture (EXIF), if recorded.
    public var captureDate: Date?

    public init(
        pixelWidth: Int,
        pixelHeight: Int,
        hasCameraMetadata: Bool = false,
        hasGPS: Bool = false,
        isScreenCapture: Bool = false,
        captureDate: Date? = nil
    ) {
        self.captureDate = captureDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.hasCameraMetadata = hasCameraMetadata
        self.hasGPS = hasGPS
        self.isScreenCapture = isScreenCapture
    }

    public var longSide: Int { max(pixelWidth, pixelHeight) }
    public var shortSide: Int { min(pixelWidth, pixelHeight) }
    public var aspect: Float {
        guard shortSide > 0 else { return 1 }
        return Float(longSide) / Float(shortSide)
    }

    public static func read(url: URL) -> ImageFacts? {
        let screenCapture = hasScreenCaptureFlag(url)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else {
            return nil
        }

        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0

        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any]

        let hasCamera =
            tiff[kCGImagePropertyTIFFMake] != nil
            || tiff[kCGImagePropertyTIFFModel] != nil
            || exif[kCGImagePropertyExifExposureTime] != nil
            || exif[kCGImagePropertyExifFNumber] != nil
            || exif[kCGImagePropertyExifLensModel] != nil

        var captured: Date?
        if let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            captured = formatter.date(from: raw)
        }

        return ImageFacts(
            pixelWidth: width,
            pixelHeight: height,
            hasCameraMetadata: hasCamera,
            hasGPS: gps != nil,
            isScreenCapture: screenCapture,
            captureDate: captured
        )
    }

    private static func hasScreenCaptureFlag(_ url: URL) -> Bool {
        url.withUnsafeFileSystemRepresentation { path in
            guard let path else { return false }
            return getxattr(path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) >= 0
        }
    }
}
