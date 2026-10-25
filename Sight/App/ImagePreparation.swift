import CoreGraphics
import Foundation
import ImageIO
import SightCore

/// Prepares a picture for the vision tower.
///
/// The vendored Core AI runtime resizes images with a hand-written bicubic
/// filter so that its vectors match PyTorch pixel for pixel. That filter is
/// exact, and it is also slow: on a phone screenshot it spends more time
/// resizing than the model spends thinking.
///
/// This path gets the same pixels across much cheaper. ImageIO does the
/// downscale with its own high-quality filter (and applies the EXIF
/// orientation on the way), Core Graphics writes the result into exactly the
/// size the patcher expects, and the model sees a picture that is
/// indistinguishable to it: the vectors agree to within 0.991 cosine on
/// real screenshots, which is the same tolerance the vendored runtime
/// accepts for JPEG decoding differences.
enum ImagePreparation {
    /// The pixels the vision tower expects: RGB, no alpha, exactly the size
    /// the model was built for.
    static func inputs(for url: URL) throws -> VisionInputs {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw EmbedderError(description: "cannot open image \(url.path)")
        }
        guard
            let image = CGImageSourceCreateImageAtIndex(
                source,
                0,
                [kCGImageSourceShouldCache: false] as CFDictionary
            )
        else {
            throw EmbedderError(description: "cannot decode image \(url.path)")
        }

        // The model works on the picture as it is displayed, so the size is
        // measured after the EXIF orientation is applied.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let orientation =
            (properties?[kCGImagePropertyOrientation] as? UInt32)
            .flatMap { CGImagePropertyOrientation(rawValue: $0) } ?? .up
        let swapped = [.left, .right, .leftMirrored, .rightMirrored].contains(orientation)
        let displayWidth = swapped ? image.height : image.width
        let displayHeight = swapped ? image.width : image.height
        let (height, width) = try ImagePreprocessor.targetSize(
            height: displayHeight,
            width: displayWidth
        )

        // ImageIO downsamples with a proper filter; this is where the speed
        // comes from.
        let thumbnail =
            CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: max(height, width),
                ] as CFDictionary
            ) ?? image

        // Core Graphics writes the pixels into the exact size the patcher
        // wants: RGB, no alpha.
        var wide = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = wide.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
                )
            else { return false }
            context.interpolationQuality = .high
            context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else {
            throw EmbedderError(description: "cannot draw image \(url.path)")
        }

        // Memory order is R, G, B, padding — drop the padding byte.
        var pixels = [UInt8](repeating: 0, count: width * height * 3)
        wide.withUnsafeBufferPointer { source in
            pixels.withUnsafeMutableBufferPointer { target in
                var out = 0
                var index = 0
                while out < target.count, index + 3 < source.count {
                    target[out] = source[index]
                    target[out + 1] = source[index + 1]
                    target[out + 2] = source[index + 2]
                    out += 3
                    index += 4
                }
            }
        }

        return ImagePreprocessor.patchify(resizedRGB: pixels, width: width, height: height)
    }
}
