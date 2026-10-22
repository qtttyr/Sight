import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Turns a file into the smallest amount of semantic signal needed for
/// classification. Sight never sends a whole document through the model:
/// a cleaned name plus a bounded prefix of the real content is enough and
/// keeps latency predictable.
public struct FileContextExtractor: Sendable {
    public static let maxTextCharacters = 6_000
    public static let maxPDFPages = 3

    private let analyzer = TypeAnalyzer()

    public init() {}

    public func extract(file: FileSnapshot) -> FileContext {
        let isImage = file.contentType.conforms(to: .image) && file.fileExtension != "svg"
        let facts = isImage ? ImageFacts.read(url: file.url) : nil
        let profile = analyzer.analyze(file: file, image: facts)

        if isImage {
            return FileContext(
                file: file,
                payload: .image(file.url),
                hint: imageHint(file: file),
                profile: profile,
                imageFacts: facts
            )
        }

        let body = readBody(of: file)
        return FileContext(
            file: file,
            payload: .text(compose(file: file, body: body)),
            profile: profile,
            body: body,
            title: documentTitle(of: file)
        )
    }

    // MARK: - Text assembly

    /// Name (cleaned), a human description of the type, and the content.
    /// The description matters for formats that cannot be read: "Microsoft
    /// Excel spreadsheet" tells the model far more than `.xlsx`.
    func compose(file: FileSnapshot, body: String) -> String {
        var parts: [String] = []
        let cleaned = NameCleaner.clean(file.name)
        if !cleaned.isEmpty { parts.append(cleaned) }
        if let description = Self.typeDescription(for: file) { parts.append(description) }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { parts.append(trimmed) }
        return parts.joined(separator: "\n\n")
    }

    /// Kept for source compatibility with callers that only have a name.
    public func compose(name: String, body: String) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = NameCleaner.clean(name)
        if trimmed.isEmpty { return cleaned.isEmpty ? name : cleaned }
        return cleaned.isEmpty ? trimmed : "\(cleaned)\n\n\(trimmed)"
    }

    private func imageHint(file: FileSnapshot) -> String? {
        let cleaned = NameCleaner.clean(file.name)
        guard NameCleaner.isInformative(cleaned) else { return nil }
        return cleaned
    }

    private static func typeDescription(for file: FileSnapshot) -> String? {
        let description = file.contentType.localizedDescription ?? ""
        if description.isEmpty || file.contentType == .data { return file.fileExtension.isEmpty ? nil : "\(file.fileExtension) file" }
        return description
    }

    private func documentTitle(of file: FileSnapshot) -> String? {
        guard file.contentType.conforms(to: .pdf) || file.fileExtension == "pdf",
              let document = PDFDocument(url: file.url),
              let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String,
              NameCleaner.isInformative(NameCleaner.clean(title))
        else { return nil }
        return title
    }

    // MARK: - Content readers

    private func readBody(of file: FileSnapshot) -> String {
        let ext = file.fileExtension
        let type = file.contentType

        if type.conforms(to: .pdf) || ext == "pdf" { return pdfText(at: file.url) }

        switch ext {
        case "docx": return attributedText(at: file.url, type: .officeOpenXML)
        case "doc": return attributedText(at: file.url, type: .docFormat)
        case "rtf": return attributedText(at: file.url, type: .rtf)
        case "rtfd": return attributedText(at: file.url, type: .rtfd)
        case "odt": return attributedText(at: file.url, type: .openDocument)
        case "html", "htm": return htmlText(at: file.url)
        case "xlsx", "pptx", "pages", "key", "numbers": return officeArchiveText(at: file.url)
        default: break
        }

        if type.conforms(to: .text) || type.conforms(to: .sourceCode)
            || type.conforms(to: .json) || type.conforms(to: .xml)
            || Self.plainTextExtensions.contains(ext) || ext.isEmpty {
            return plainText(at: file.url)
        }
        return ""
    }

    private static let plainTextExtensions: Set<String> = [
        "txt", "md", "markdown", "csv", "tsv", "json", "jsonl", "yaml", "yml", "toml", "xml",
        "css", "scss", "js", "ts", "tsx", "jsx", "swift", "py", "rb", "go", "rs", "java", "kt",
        "c", "h", "cpp", "hpp", "m", "mm", "sh", "zsh", "fish", "sql", "log", "ini", "conf",
        "env", "tex", "srt", "vtt"
    ]

    private func plainText(at url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: Self.maxTextCharacters * 4)) ?? Data()
        guard !data.isEmpty else { return "" }
        // Binary blobs (gguf, models) must not be fed as "text".
        if data.prefix(2048).contains(0) { return "" }
        let decoded = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .utf16)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        return String(decoded.prefix(Self.maxTextCharacters))
    }

    private func pdfText(at url: URL) -> String {
        guard let document = PDFDocument(url: url) else { return "" }
        var pieces: [String] = []
        if let title = document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String,
           NameCleaner.isInformative(title) {
            pieces.append(title)
        }
        for index in 0..<min(document.pageCount, Self.maxPDFPages) {
            if let text = document.page(at: index)?.string, !text.isEmpty {
                pieces.append(text)
            }
        }
        return String(pieces.joined(separator: "\n").prefix(Self.maxTextCharacters))
    }

    private func attributedText(at url: URL, type: NSAttributedString.DocumentType) -> String {
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [.documentType: type]
        if let attributed = try? NSAttributedString(url: url, options: options, documentAttributes: nil) {
            return String(attributed.string.prefix(Self.maxTextCharacters))
        }
        // Wrong or missing extension: let AppKit sniff the format.
        if let attributed = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
            return String(attributed.string.prefix(Self.maxTextCharacters))
        }
        return ""
    }

    /// HTML is stripped by hand: the AppKit importer needs the main thread
    /// and a web view, which has no place in a background sweep.
    private func htmlText(at url: URL) -> String {
        var raw = plainText(at: url)
        guard !raw.isEmpty else { return "" }
        for tag in ["script", "style"] {
            raw = raw.replacingOccurrences(
                of: "<\(tag)[\\s\\S]*?</\(tag)>",
                with: " ",
                options: [.regularExpression, .caseInsensitive]
            )
        }
        raw = raw.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        raw = raw.replacingOccurrences(of: "&nbsp;", with: " ")
        raw = raw.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return String(raw.prefix(Self.maxTextCharacters))
    }

    /// xlsx / pptx / pages / key / numbers are ZIP containers. A few of them
    /// carry a text preview or XML we can read cheaply; the rest fall back to
    /// the type description. Returns an empty string when nothing is readable.
    private func officeArchiveText(at url: URL) -> String {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe),
              let archive = ZipTextPeek(data: data)
        else { return "" }
        return String(archive.readableText().prefix(Self.maxTextCharacters))
    }
}
