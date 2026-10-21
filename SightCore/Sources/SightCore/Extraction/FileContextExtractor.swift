import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Turns a file into the smallest amount of semantic signal needed for
/// classification. Sight never sends a whole document through the model:
/// filenames plus a bounded prefix are enough for zero-shot routing and keep
/// latency predictable.
public struct FileContextExtractor: Sendable {
    public static let maxTextCharacters = 8_000
    public static let maxPDFPages = 3

    private static let richTextExtensions: Set<String> = [
        "doc", "docx", "rtf", "rtfd", "html", "htm", "odt", "webarchive"
    ]

    public init() {}

    public func extract(file: FileSnapshot) -> FileContext {
        let name = file.name
        let lowercasedExtension = file.fileExtension

        if file.contentType.conforms(to: .image) {
            return FileContext(file: file, payload: .image(file.url))
        }

        if file.contentType.conforms(to: .pdf) || lowercasedExtension == "pdf" {
            let text = pdfText(at: file.url)
            return FileContext(file: file, payload: .text(compose(name: name, body: text)))
        }

        if Self.richTextExtensions.contains(lowercasedExtension) {
            let text = richText(at: file.url)
            return FileContext(file: file, payload: .text(compose(name: name, body: text)))
        }

        if file.contentType.conforms(to: .text)
            || file.contentType.conforms(to: .sourceCode)
            || isLikelyPlainText(lowercasedExtension) {
            let text = plainText(at: file.url)
            return FileContext(file: file, payload: .text(compose(name: name, body: text)))
        }

        // Unknown binary formats still carry a useful signal in their name and
        // type. This keeps ZIPs, archives and future formats routable without
        // pretending that their contents were read.
        let fallback = "\(name)\n\(file.contentType.identifier)"
        return FileContext(file: file, payload: .text(fallback))
    }

    public func compose(name: String, body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return name }
        return "\(name)\n\n\(trimmed)"
    }

    private func plainText(at url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: Self.maxTextCharacters * 4)) ?? Data()
        guard !data.isEmpty else { return "" }
        let decoded = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        return String(decoded.prefix(Self.maxTextCharacters))
    }

    private func pdfText(at url: URL) -> String {
        guard let document = PDFDocument(url: url) else { return "" }
        var pages: [String] = []
        for index in 0..<min(document.pageCount, Self.maxPDFPages) {
            if let text = document.page(at: index)?.string, !text.isEmpty {
                pages.append(text)
            }
        }
        return String(pages.joined(separator: "\n").prefix(Self.maxTextCharacters))
    }

    private func richText(at url: URL) -> String {
        guard let attributed = try? NSAttributedString(
            url: url,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ) else {
            return ""
        }
        return String(attributed.string.prefix(Self.maxTextCharacters))
    }

    private func isLikelyPlainText(_ fileExtension: String) -> Bool {
        let extensions: Set<String> = [
            "txt", "md", "markdown", "csv", "tsv", "json", "yaml", "yml", "toml",
            "xml", "html", "css", "scss", "js", "ts", "tsx", "jsx", "swift", "py",
            "rb", "go", "rs", "java", "kt", "c", "h", "cpp", "hpp", "m", "mm",
            "sh", "zsh", "fish", "sql", "log", "ini", "conf", "env", "gitignore"
        ]
        return extensions.contains(fileExtension)
    }
}
