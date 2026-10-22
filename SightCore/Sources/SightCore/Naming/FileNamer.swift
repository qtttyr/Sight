import Foundation

/// One possible name for a file.
public struct NameCandidate: Sendable {
    public let text: String
    /// Template names come from a recognised document type and are trusted
    /// without a semantic check; every other candidate must prove it fits.
    public let isTemplate: Bool
    /// Small bonus for candidates that come from prominent places (titles).
    public let prior: Float
}

/// Proposes a short, clear, topical name (two or three words) for a file
/// whose current name tells you nothing (`scan_0041.pdf`, `IMG_0059.PNG`).
///
/// The rules are deliberately conservative, because a wrong rename is worse
/// than no rename:
/// - A name that already says something is never touched.
/// - Code, archives, installers, fonts, audio and video keep their names.
/// - Candidates come from the file itself (titles, recognised document
///   types, headings in screenshots); the best one is chosen by meaning
///   in `Sorter`, and nothing is renamed without a convincing candidate.
/// - Every rename is undoable: the journal remembers the original name.
public struct FileNamer: Sendable {
    public static let maxWords = 3

    public init() {}

    private static let keepNames: [FileKind] = [.code, .archives, .design, .audio, .video]

    /// Should this file even be considered for a new name?
    public func isRenameable(_ context: FileContext) -> Bool {
        let file = context.file
        for kind in Self.keepNames where (context.profile.boosts[kind] ?? 0) >= 0.7 { return false }
        if file.fileExtension.isEmpty { return false }
        let cleaned = NameCleaner.clean(file.name)
        return !NameCleaner.isInformative(cleaned) || Self.looksMachineMade(file.name)
    }

    /// Candidates plus the text they should be judged against.
    public func candidates(for context: FileContext, allowOCR: Bool = true) -> (candidates: [NameCandidate], reference: String) {
        if let url = context.imageURL { return imageCandidates(context: context, url: url, allowOCR: allowOCR) }
        return documentCandidates(context: context)
    }

    /// Final extension handling and sanity checks for a chosen title.
    public func finalName(title: String, for file: FileSnapshot) -> String? {
        guard let safe = Self.sanitize(title) else { return nil }
        let currentBase = (file.name as NSString).deletingPathExtension
        if safe.caseInsensitiveCompare(currentBase) == .orderedSame { return nil }
        return "\(safe).\(file.url.pathExtension)"
    }

    // MARK: - Images

    private func imageCandidates(context: FileContext, url: URL, allowOCR: Bool) -> ([NameCandidate], String) {
        if let facts = context.imageFacts, facts.hasCameraMetadata, let date = facts.captureDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            return ([NameCandidate(text: "Photo \(formatter.string(from: date))", isTemplate: true, prior: 0)], "")
        }
        guard allowOCR else { return ([], "") }

        let lines = ImageTextReader.lines(of: url).filter { $0.confidence >= 0.6 }
        guard !lines.isEmpty else { return ([], "") }
        let reference = lines.prefix(12).map(\.text).joined(separator: "\n")

        var result: [NameCandidate] = []
        for (rank, line) in lines.prefix(4).enumerated() {
            let text = line.text
            guard text.filter(\.isLetter).count * 10 >= text.count * 7 else { continue }
            let bonus = Float(0.12 - 0.03 * Double(rank))
            for phrase in PhraseExtractor.phrases(from: text) {
                result.append(NameCandidate(text: phrase, isTemplate: false, prior: bonus))
            }
        }
        return (result, reference)
    }

    // MARK: - Documents

    private static let documentTypes: [(label: String, markers: [String])] = [
        ("Invoice", ["invoice", "счёт на оплату", "счет на оплату", "счёт №", "счет №"]),
        ("Receipt", ["receipt", "кассовый чек", "квитанция"]),
        ("NDA", ["non-disclosure", "соглашение о неразглашении"]),
        ("Contract", ["services agreement", "agreement", "contract", "договор"]),
        ("Resume", ["curriculum vitae", "resume", "резюме"]),
        ("Cover letter", ["dear hiring", "cover letter", "сопроводительное письмо"]),
        ("Offer letter", ["offer of employment", "offer letter"]),
        ("Bank statement", ["account statement", "bank statement", "выписка по счёту", "выписка по счету"]),
        ("Payslip", ["payslip", "pay slip", "расчётный листок", "расчетный листок"]),
        ("Tax return", ["tax return", "налоговая декларация"]),
        ("Purchase order", ["purchase order"]),
        ("Quotation", ["quotation", "коммерческое предложение"]),
        ("Proposal", ["project proposal", "business proposal"])
    ]

    private static let counterpartyPattern =
        #"(?:bill(?:ed)? to|client|customer|vendor|prepared for|покупатель|заказчик|поставщик)[:\s]+([^\n,.;]{3,40})"#

    private func documentCandidates(context: FileContext) -> ([NameCandidate], String) {
        let body = context.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = String(body.prefix(1_500))
        let lower = head.lowercased()
        var result: [NameCandidate] = []

        // 1. A recognised document type: "Invoice Northwind", "Payslip Aug 2026".
        for entry in Self.documentTypes where entry.markers.contains(where: { lower.contains($0) }) {
            var name = entry.label
            if let party = Self.firstCapture(Self.counterpartyPattern, in: head),
               let short = Self.shorten(party, to: 2) {
                name += " \(short)"
            } else if let month = Self.monthYear(in: head) {
                name += " \(month)"
            } else if let line = Self.titleLines(in: head, excluding: entry.label).first,
                      let short = PhraseExtractor.phrases(from: line).first.flatMap({ Self.shorten($0, to: 2) }) {
                name += " \(short)"
            }
            result.append(NameCandidate(text: name, isTemplate: true, prior: 0.3))
            break
        }

        // 2. Titles and headings, reduced to their core phrase.
        var lines: [(String, Float)] = []
        if let title = context.title { lines.append((title, 0.15)) }
        for (index, line) in Self.titleLines(in: head, excluding: nil).prefix(3).enumerated() {
            lines.append((line, 0.12 - 0.03 * Float(index)))
        }
        for (line, prior) in lines {
            let words = line.split(separator: " ")
            if words.count <= Self.maxWords { result.append(NameCandidate(text: line, isTemplate: false, prior: prior)) }
            for phrase in PhraseExtractor.phrases(from: line) {
                result.append(NameCandidate(text: phrase, isTemplate: false, prior: prior))
            }
        }
        return (result, String(body.prefix(1_200)))
    }

    /// Lines that read like headings rather than sentences.
    static func titleLines(in text: String, excluding label: String?) -> [String] {
        var found: [String] = []
        for line in text.split(whereSeparator: \.isNewline).prefix(8) {
            let text = line.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "#*>-•")))
            let words = text.split(separator: " ")
            let letters = text.filter(\.isLetter).count
            guard (2...9).contains(words.count), (8...80).contains(text.count),
                  letters * 10 >= text.count * 6,
                  !text.hasSuffix("."), !text.contains("@"), !text.lowercased().contains("http"),
                  text.first?.isUppercase == true || text.first?.isNumber == true
            else { continue }
            if let label, text.lowercased().contains(label.lowercased()) { continue }
            found.append(text)
        }
        return found
    }

    // MARK: - Helpers

    static func looksMachineMade(_ name: String) -> Bool {
        let base = (name as NSString).deletingPathExtension
        guard !base.isEmpty else { return true }
        let digits = base.filter(\.isNumber).count
        return Double(digits) / Double(base.count) > 0.3
    }

    /// Makes a title safe to use as a file name: no illegal characters, no
    /// digits-only noise, and never more than `maxWords` words.
    static func sanitize(_ title: String) -> String? {
        var text = title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters))
            .joined(separator: " ")
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ".-–,;")))
        let words = text.split(separator: " ")
        guard !words.isEmpty, words.count <= maxWords else { return nil }
        guard text.count >= 5, text.count <= 40 else { return nil }
        guard text.filter(\.isLetter).count * 10 >= text.count * 7 else { return nil }
        return text
    }

    static func shorten(_ text: String, to count: Int) -> String? {
        let cleaned = text.replacingOccurrences(of: "[^\\p{L}\\s&-]", with: " ", options: .regularExpression)
        let words = cleaned.split(separator: " ").prefix(count)
        guard !words.isEmpty else { return nil }
        return PhraseExtractor.tidy(words.map(String.init))
    }

    private static func monthYear(in text: String) -> String? {
        let months = ["january", "february", "march", "april", "may", "june", "july", "august",
                      "september", "october", "november", "december"]
        let lower = text.lowercased()
        for (index, month) in months.enumerated() where lower.contains(month) {
            let short = month.prefix(3).capitalized
            if let year = firstCapture(#"(20\d{2})"#, in: text) { return "\(short) \(year)" }
            _ = index
            return short
        }
        return nil
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
