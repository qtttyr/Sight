import Foundation
import UniformTypeIdentifiers

/// Reads the cheapest and most reliable signals a file carries: its type, its
/// name conventions and, for images, how it was made. Everything here is a
/// table lookup or a metadata read, so it costs microseconds and never gets
/// "confused" the way an embedding can.
public struct TypeAnalyzer: Sendable {
    public init() {}

    // MARK: - Tables

    private static let video: Set<String> = [
        "mp4", "mov", "m4v", "mkv", "avi", "webm", "mpg", "mpeg", "wmv", "flv", "3gp", "mts", "m2ts",
    ]
    private static let audio: Set<String> = [
        "mp3", "wav", "flac", "aac", "m4a", "ogg", "opus", "aiff", "aif", "wma", "caf", "amr", "mid", "midi",
    ]
    private static let archives: Set<String> = [
        "zip", "tgz", "gz", "tar", "rar", "7z", "dmg", "pkg", "iso", "xz", "bz2", "zst", "cab", "mpkg", "xip",
    ]
    private static let sourceCode: Set<String> = [
        "swift", "py", "js", "jsx", "tsx", "rb", "go", "rs", "java", "kt", "c", "h", "cpp", "hpp",
        "m", "mm", "cs", "php", "sh", "zsh", "bash", "fish", "sql", "lua", "dart", "r", "scala",
        "pl", "css", "scss", "ipynb", "gradle", "xcconfig", "pbxproj", "entitlements",
    ]
    private static let dataAndConfig: Set<String> = [
        "json", "jsonl", "yaml", "yml", "toml", "xml", "ini", "conf", "env", "plist", "log",
        "gguf", "safetensors", "ckpt", "pt", "pth", "onnx", "mlmodel", "mlpackage", "parquet",
    ]
    private static let devFileNames: Set<String> = [
        "dockerfile", "makefile", "modelfile", "podfile", "gemfile", "procfile", "brewfile",
        "rakefile", "vagrantfile", "cmakelists.txt", "requirements.txt", "package.json",
    ]
    private static let design: Set<String> = [
        "psd", "psb", "ai", "eps", "indd", "sketch", "fig", "xd", "afdesign", "afphoto", "afpub",
        "ttf", "otf", "woff", "woff2", "ttc", "blend", "obj", "fbx", "stl", "usdz", "glb", "gltf",
        "c4d", "icns", "ico", "svg", "figma",
    ]
    private static let documents: Set<String> = [
        "pdf", "doc", "docx", "pages", "rtf", "rtfd", "txt", "md", "markdown", "odt", "tex", "epub", "mobi", "djvu",
    ]
    private static let ebooks: Set<String> = ["epub", "mobi", "djvu"]
    private static let office: Set<String> = [
        "xls", "xlsx", "numbers", "ppt", "pptx", "key", "ods", "odp",
    ]
    private static let tabular: Set<String> = ["csv", "tsv"]
    private static let cameraRaw: Set<String> = ["dng", "raw", "cr2", "cr3", "nef", "arw", "orf", "rw2"]
    private static let photoFormats: Set<String> = ["jpg", "jpeg", "heic", "heif", "tif", "tiff"]

    /// Pixel sizes (short side, long side) of real screens. A PNG with exactly
    /// one of these dimensions and no camera metadata is a screen capture.
    private static let screenSizes: Set<[Int]> = [
        // iPhone
        [640, 1136], [750, 1334], [828, 1792], [1080, 1920], [1080, 2340], [1080, 2400],
        [1125, 2436], [1170, 2532], [1179, 2556], [1206, 2622], [1242, 2208], [1242, 2688],
        [1284, 2778], [1290, 2796], [1320, 2868],
        // iPad
        [1536, 2048], [1620, 2160], [1640, 2360], [1668, 2224], [1668, 2388], [2048, 2732], [2064, 2752],
        // Mac and external displays
        [900, 1440], [1117, 1728], [1329, 2056], [800, 1280], [1440, 2560], [1600, 2560],
        [1800, 2880], [1050, 1680], [956, 1470], [982, 1512], [1112, 1728], [1212, 1940],
        [1440, 2304], [1964, 3024], [2234, 3456], [1080, 1920], [1440, 3440], [2160, 3840],
        [2880, 5120], [1912, 2940], [2100, 3360], [1200, 1920],
    ]

    /// Widths of real phone and tablet screens. A JPEG or PNG exactly this
    /// wide, with no camera metadata, is a screen capture that was cropped.
    private static let screenWidths: Set<Int> = [
        640, 750, 828, 1080, 1125, 1170, 1179, 1206, 1242, 1284, 1290, 1320, 1536, 1620, 1640, 1668, 2048, 2064,
    ]

    private static let screenshotName =
        #"^(screenshot|screen ?shot|screen capture|screen recording|снимок экрана|скриншот|запись экрана|bildschirmfoto|capture d.écran|captura de pantalla|schermafbeelding|スクリーンショット)"#

    private static let cameraName =
        #"^(img|dsc|dscn|dscf|pxl|mvimg|mvi|dji|gopr|p)[ _-]?\d{3,}|^photo[ _]\d{4}-\d{2}-\d{2}|^img-\d{8}-wa\d+|^whatsapp image|^telegram|^\d{8}[ _]\d{6}|^фото[ _]"#

    private static let designName =
        #"(logo|icon|mockup|wireframe|banner|poster|brand|illustration|sprite|atlas|texture|render|artwork|vector|palette|moodboard|favicon|thumbnail|flyer|brochure)"#

    private static func matches(_ pattern: String, _ text: String) -> Bool {
        text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    // MARK: - Analysis

    public func analyze(file: FileSnapshot, image: ImageFacts? = nil) -> TypeProfile {
        var profile = TypeProfile()
        let ext = file.fileExtension
        let lowerName = file.name.lowercased()
        let type = file.contentType

        if Self.video.contains(ext) || (type.conforms(to: .movie) && !type.conforms(to: .image)) {
            profile.boost(.video, 0.98, because: "Video file (.\(ext))")
            profile.exclude(.documents, .work, .code)
            return profile
        }
        if Self.audio.contains(ext) || type.conforms(to: .audio) {
            profile.boost(.audio, 0.98, because: "Audio file (.\(ext))")
            profile.exclude(.documents, .work, .code, .photos, .screenshots)
            return profile
        }
        if Self.archives.contains(ext) || type.conforms(to: .archive) || type.conforms(to: .diskImage) {
            profile.boost(.archives, 0.97, because: "Archive or installer (.\(ext))")
            profile.exclude(.documents, .work, .photos, .screenshots)
            return profile
        }
        if Self.design.contains(ext) {
            let strength: Float = ext == "svg" ? 0.88 : 0.95
            profile.boost(.design, strength, because: "Design format (.\(ext))")
            profile.exclude(.video, .audio, .archives)
            return profile
        }
        if ext.isEmpty, Self.devFileNames.contains(lowerName) {
            profile.boost(.code, 0.92, because: "Developer file (\(file.name))")
            profile.exclude(.video, .audio, .photos, .screenshots)
            return profile
        }
        if Self.devFileNames.contains(lowerName) {
            profile.boost(.code, 0.8, because: "Developer file (\(file.name))")
        }
        if Self.sourceCode.contains(ext) {
            profile.boost(.code, 0.97, because: "Source code (.\(ext))")
            profile.exclude(.video, .audio, .photos, .screenshots, .documents)
            return profile
        }
        if Self.dataAndConfig.contains(ext) {
            profile.boost(.code, 0.72, because: "Data or config file (.\(ext))")
            profile.exclude(.video, .audio, .photos, .screenshots)
            return profile
        }
        if Self.office.contains(ext) {
            profile.boost(.work, 0.55, because: "Office file (.\(ext))")
            profile.exclude(.video, .audio, .archives, .photos, .screenshots, .code)
            return profile
        }
        if Self.tabular.contains(ext) {
            profile.boost(.work, 0.3, because: "Spreadsheet data (.\(ext))")
            profile.exclude(.video, .audio, .archives, .photos, .screenshots)
            return profile
        }
        if Self.ebooks.contains(ext) {
            profile.boost(.documents, 0.85, because: "E-book (.\(ext))")
            profile.exclude(.video, .audio, .archives, .photos, .screenshots, .code)
            return profile
        }
        if Self.documents.contains(ext) {
            profile.exclude(.video, .audio, .archives, .photos, .screenshots)
            // Plain text and markdown are often notes or READMEs; only real
            // document formats rule out Code.
            if !["txt", "md", "markdown", "tex"].contains(ext) { profile.exclude(.code) }
            return profile
        }
        if type.conforms(to: .image) || Self.cameraRaw.contains(ext) {
            analyzeImage(file: file, facts: image, into: &profile)
            return profile
        }
        if type.conforms(to: .html) || ext == "html" || ext == "htm" || ext == "webarchive" {
            profile.exclude(.video, .audio, .archives, .photos, .screenshots)
            return profile
        }
        return profile
    }

    private func analyzeImage(file: FileSnapshot, facts: ImageFacts?, into profile: inout TypeProfile) {
        profile.exclude(.video, .audio, .archives, .code)
        let ext = file.fileExtension
        let name = file.name

        let namedScreenshot = Self.matches(Self.screenshotName, name)
        if namedScreenshot {
            profile.boost(.screenshots, 0.97, because: "Named like a screenshot")
        }
        if facts?.isScreenCapture == true {
            profile.boost(.screenshots, 0.97, because: "Marked by macOS as a screen capture")
        }

        if ext == "gif" {
            profile.boost(.photos, 0.45, because: "Animated GIF")
        }

        if Self.cameraRaw.contains(ext) {
            profile.boost(.photos, 0.97, because: "Camera RAW photo (.\(ext))")
            profile.exclude(.screenshots)
            return
        }

        if let facts {
            if facts.hasCameraMetadata || facts.hasGPS {
                profile.boost(.photos, 0.95, because: "Camera metadata found in the image")
                profile.exclude(.screenshots)
                return
            }

            let sizeKey = [facts.shortSide, facts.longSide]
            let isScreenSize = Self.screenSizes.contains(sizeKey)
            let isCroppedScreen =
                !isScreenSize
                && Self.screenWidths.contains(facts.pixelWidth)
                && facts.pixelHeight <= 2_900
            if isCroppedScreen, ext != "gif" {
                profile.boost(.screenshots, 0.6, because: "Exactly as wide as a phone screen, no camera data")
            }
            if ext == "png" {
                if isScreenSize {
                    profile.boost(.screenshots, 0.9, because: "PNG with the exact size of a device screen")
                } else if !namedScreenshot, !Self.matches(Self.designName, name) {
                    // A PNG without camera data is most often a capture or an
                    // export; vision and the file name decide between them.
                    profile.boost(.screenshots, 0.3, because: "PNG without camera metadata")
                }
            }
        }

        if Self.matches(Self.designName, name) {
            profile.boost(.design, 0.55, because: "Named like a design asset")
        }

        if Self.photoFormats.contains(ext), Self.matches(Self.cameraName, name),
            profile.boosts[.screenshots] == nil
        {
            profile.boost(.photos, 0.3, because: "Named like a camera photo")
        }
    }
}
