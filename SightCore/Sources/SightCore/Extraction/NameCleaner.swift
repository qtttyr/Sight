import Foundation

/// Turns a raw file name into text a language model can actually read.
///
/// `Student worksheet_Critical reading 1_evaluating sources.docx` becomes
/// `Student worksheet Critical reading evaluating sources`, while camera
/// names such as `IMG_0059.PNG` are recognised as carrying no meaning.
public enum NameCleaner {
    /// Words that appear in file names but say nothing about the content.
    private static let genericWords: Set<String> = [
        "img", "image", "images", "dsc", "dscn", "dscf", "pxl", "photo", "photos",
        "picture", "pic", "pics", "scan", "scanned", "untitled", "new", "copy", "final",
        "download", "downloads", "file", "files", "document", "doc", "screenshot",
        "screen", "shot", "capture", "mvimg", "video", "vid", "audio", "unknown",
        "temp", "tmp", "draft", "version", "edited", "export", "exported", "whatsapp",
        "telegram", "attachment", "noname", "mov", "mp4", "png", "jpg", "jpeg", "heic"
    ]

    public static func clean(_ fileName: String) -> String {
        var base = (fileName as NSString).deletingPathExtension
        if base.isEmpty { base = fileName }

        // camelCase → words
        base = base.replacingOccurrences(
            of: "([a-z0-9])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        // separators → spaces
        base = base.replacingOccurrences(
            of: "[_\\-\\.\\+~]+",
            with: " ",
            options: .regularExpression
        )
        // "(1)", "[2]" duplicate markers
        base = base.replacingOccurrences(
            of: "[\\(\\[]\\d+[\\)\\]]",
            with: " ",
            options: .regularExpression
        )

        let words = base
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
            .filter { token in
                if token.allSatisfy(\.isNumber) {
                    // Keep plausible years ("tax return 2025"), drop every
                    // other bare number: counters, timestamps, ids.
                    guard token.count == 4, let year = Int(token) else { return false }
                    return (1990...2099).contains(year)
                }
                // Hashes and ids: long hex-looking tokens.
                if token.count >= 8, token.allSatisfy(\.isHexDigit) { return false }
                return true
            }
        return words.joined(separator: " ")
    }

    /// True when the cleaned name contains at least one real word, i.e. the
    /// name is worth embedding. `IMG 0059` is not; `pixel art kitchen atlas` is.
    public static func isInformative(_ cleaned: String) -> Bool {
        let words = cleaned
            .lowercased()
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { $0.count >= 2 && !genericWords.contains($0) }
        return !words.isEmpty
    }
}
