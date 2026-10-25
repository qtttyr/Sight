import Foundation

/// One possible name for a file.
public struct NameCandidate: Sendable {
    public let text: String
    /// Template names come from a recognised document type or from the
    /// document's own title metadata and are trusted without a semantic check;
    /// every other candidate must prove it fits.
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
    /// A name has to stay readable in a Finder window.
    public static let minCharacters = 4
    public static let maxCharacters = 40
    /// How much better the winner has to be than the runner-up before a
    /// non-template candidate is used. Below this the choice is a coin flip.
    public static let decisionMargin: Float = 0.03

    public init() {}

    private static let keepNames: [FileKind] = [.code, .archives, .design, .audio, .video]

    // MARK: - What may be renamed

    /// Should this file even be considered for a new name?
    public func isRenameable(_ context: FileContext) -> Bool {
        let file = context.file
        for kind in Self.keepNames where (context.profile.boosts[kind] ?? 0) >= 0.7 { return false }
        if file.fileExtension.isEmpty { return false }
        let cleaned = NameCleaner.clean(file.name)
        return !NameCleaner.isInformative(cleaned) || Self.looksMachineMade(file.name)
    }

    /// Candidates plus the text they should be judged against.
    public func candidates(
        for context: FileContext, allowOCR: Bool = true
    ) -> (candidates: [NameCandidate], reference: String) {
        if let url = context.imageURL { return imageCandidates(context: context, url: url, allowOCR: allowOCR) }
        return documentCandidates(context: context)
    }

    /// Picks the candidate that best fits the file.
    ///
    /// Templates are trusted: they come from the document's own title or from
    /// a recognised document type, and no semantic check can improve on them.
    /// Every other candidate has to win by a clear margin — a name that is
    /// only slightly better than its rivals is a guess, and a wrong rename is
    /// worse than no rename.
    public static func select(_ candidates: [NameCandidate], scores: [Float]) -> NameCandidate? {
        guard !candidates.isEmpty else { return nil }

        var usable: [(candidate: NameCandidate, score: Float, similarity: Float)] = []
        for (index, candidate) in candidates.enumerated() {
            guard sanitize(candidate.text) != nil else { continue }
            let similarity = index < scores.count ? scores[index] : 0
            usable.append((candidate, similarity + candidate.prior, similarity))
        }
        guard !usable.isEmpty else { return nil }

        if let best = usable.filter({ $0.candidate.isTemplate }).max(by: { $0.score < $1.score }) {
            return best.candidate
        }

        // A verified candidate needs a runner-up to beat: with a single
        // candidate there is nothing to compare it against.
        guard usable.count >= 2 else { return nil }
        let ranked = usable.sorted { $0.score > $1.score }
        guard ranked[0].score - ranked[1].score >= decisionMargin else { return nil }
        // The winner has to be the closest to the file's own meaning too; a
        /// prior must not be able to overrule the semantics.
        guard ranked[0].similarity >= ranked[1].similarity - 0.01 else { return nil }
        return ranked[0].candidate
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

        let lines = ImageTextReader.lines(of: url).filter { $0.confidence >= 0.8 }
        guard !lines.isEmpty else { return ([], "") }
        let reference = lines.prefix(12).map(\.text).joined(separator: "\n")

        var result: [NameCandidate] = []
        // The reader sorts by text height, so the tallest lines are the
        // headings — exactly what a name should be built from.
        for (rank, line) in lines.prefix(4).enumerated() {
            guard Self.looksLikeHeading(line.text) else { continue }
            let bonus = Float(0.12 - 0.03 * Double(rank))
            let title = Self.trimToTitle(line.text)
            if let title {
                result.append(NameCandidate(text: title, isTemplate: false, prior: bonus))
            }
            for phrase in PhraseExtractor.phrases(from: line.text) {
                guard let trimmed = Self.trimToTitle(phrase), trimmed != title else { continue }
                result.append(NameCandidate(text: trimmed, isTemplate: false, prior: bonus - 0.02))
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
        ("Tax return", ["tax return", "налоговая деклорация"]),
        ("Purchase order", ["purchase order"]),
        ("Quotation", ["quotation", "коммерческое предложение"]),
        ("Proposal", ["project proposal", "business proposal"]),
    ]

    private static let counterpartyPattern =
        #"(?:bill(?:ed)? to|client|customer|vendor|prepared for|покупатель|заказчик|поставщик)[:\s]+([^\n,.;]{3,40})"#

    private func documentCandidates(context: FileContext) -> ([NameCandidate], String) {
        let body = context.body.trimmingCharacters(in: .whitespacesAndNewlines)
        let head = String(body.prefix(1_500))
        let lower = head.lowercased()
        var result: [NameCandidate] = []

        // 1. The document's own title metadata: the most reliable name there is.
        if let title = context.title, let trimmed = Self.trimToTitle(title) {
            result.append(NameCandidate(text: trimmed, isTemplate: true, prior: 0.4))
        }

        // 2. A recognised document type: "Invoice Northwind", "Payslip".
        for entry in Self.documentTypes where entry.markers.contains(where: { lower.contains($0) }) {
            var name = entry.label
            if let party = Self.firstCapture(Self.counterpartyPattern, in: head),
                let short = Self.shorten(party, to: 2), Self.looksLikeHeading(short)
            {
                name += " \(short)"
            } else if let month = Self.monthYear(in: head) {
                name += " \(month)"
            }
            if let trimmed = Self.trimToTitle(name) {
                result.append(NameCandidate(text: trimmed, isTemplate: true, prior: 0.3))
            }
            break
        }

        // 3. Headings in the body. They need a semantic check like everything
        //    else: a document may contain a dozen of them.
        var lines: [(String, Float)] = []
        if let title = context.title { lines.append((title, 0.15)) }
        for (index, line) in Self.titleLines(in: head, excluding: nil).prefix(3).enumerated() {
            lines.append((line, 0.12 - 0.03 * Float(index)))
        }
        for (line, prior) in lines {
            for phrase in PhraseExtractor.phrases(from: line) {
                guard let trimmed = Self.trimToTitle(phrase) else { continue }
                result.append(NameCandidate(text: trimmed, isTemplate: false, prior: prior))
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
            guard looksLikeHeading(text) else { continue }
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

    /// Words that never end a title and never start one.
    static let functionWords: Set<String> = [
        "a", "an", "and", "are", "as", "at", "be", "been", "by", "for", "from", "in", "into",
        "is", "it", "its", "of", "on", "or", "that", "the", "their", "this", "to", "was",
        "were", "with", "you", "your",
        "а", "без", "бы", "был", "была", "в", "во", "все", "всё", "где", "для", "до", "его",
        "ее", "её", "же", "за", "и", "из", "или", "их", "к", "как", "кто", "ли", "мы", "на",
        "наш", "не", "но", "о", "об", "от", "по", "под", "при", "про", "с", "со", "так", "то",
        "ты", "у", "их", "это", "я",
    ]

    /// A heading is a short phrase that reads like a title, not like a
    /// sentence. "Service Concept" is one; "Discovery became much more
    /// visual" is not.
    public static func looksLikeHeading(_ text: String) -> Bool {
        let words = text.split(separator: " ")
        guard (1...4).contains(words.count) else { return false }
        guard text.count >= 4, text.count <= 40 else { return false }
        // Sentences end with a dot; titles do not.
        guard !text.hasSuffix(".") else { return false }
        guard !text.contains("://"), !text.contains("@") else { return false }
        // "L.V" and "Н1." are broken words, not headings. A dot after a digit
        // is fine: "2.0" is a version.
        guard !words.contains(where: { Self.endsWithLetterDot($0) }) else { return false }

        let capitalised = words.filter { word in
            guard let first = word.first else { return false }
            return first.isUppercase || first.isNumber
        }.count
        // Title case, all caps, or a capitalised first word: a title.
        if Double(capitalised) / Double(words.count) >= 0.6 { return true }
        // Sentence case is only accepted for very short phrases without
        // function words — a Russian heading, but not an English sentence.
        let functions = words.filter { functionWords.contains($0.lowercased()) }.count
        return functions == 0 && words.count <= 3 && capitalised >= 1
    }

    /// True when a word ends in a dot that follows a letter ("L.V"), which
    /// means the word was cut in half.
    static func endsWithLetterDot(_ word: some StringProtocol) -> Bool {
        guard word.count >= 2, word.hasSuffix(".") else { return false }
        let before = word.dropLast().last
        guard let before else { return false }
        return before.isLetter
    }
    /// Trims a phrase to something that reads like a title: at most three
    /// words, no dangling function word, first letter capitalised.
    public static func trimToTitle(_ phrase: String, maxWords: Int = FileNamer.maxWords) -> String? {
        var words =
            phrase
            .replacingOccurrences(of: "[–—]", with: " ", options: .regularExpression)
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
        while let last = words.last, functionWords.contains(last.lowercased()) {
            words.removeLast()
        }
        while let first = words.first, functionWords.contains(first.lowercased()), words.count > 1 {
            words.removeFirst()
        }
        guard !words.isEmpty else { return nil }
        if words.count > maxWords { words = Array(words.prefix(maxWords)) }
        while let last = words.last, functionWords.contains(last.lowercased()), words.count > 1 {
            words.removeLast()
        }
        var text = words.joined(separator: " ")
        guard let first = text.first else { return nil }
        text = first.uppercased() + text.dropFirst()
        return text
    }

    /// Makes a title safe to use as a file name: no illegal characters, no
    /// stray numbers, no dangling function word, and never more than
    /// `maxWords` words.
    public static func sanitize(_ title: String) -> String? {
        var text =
            title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters))
            .joined(separator: " ")
        text = text.replacingOccurrences(of: "[–—]", with: " ", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: ".-–,;")))
        let words = text.split(separator: " ")
        guard !words.isEmpty, words.count <= maxWords else { return nil }
        guard text.count >= minCharacters, text.count <= maxCharacters else { return nil }
        // Letters and digits both carry meaning; punctuation does not.
        let meaningful = text.filter { $0.isLetter || $0.isNumber }.count
        guard meaningful * 10 >= text.count * 7 else { return nil }
        // Numbers are noise unless they are a version or a year.
        for word in words {
            guard word.contains(where: \.isNumber) else { continue }
            let isVersion =
                Self.versionPattern.firstMatch(
                    in: String(word),
                    range: NSRange(word.startIndex..., in: word)
                ) != nil
            let isYear = word.count == 4 && Int(word).map { (1990...2099).contains($0) } == true
            guard isVersion || isYear else { return nil }
        }
        return text
    }

    /// "2.0" and "2.0.1" are versions; "312.00" is money.
    private static let versionPattern = try! NSRegularExpression(
        pattern: #"^\d{1,2}(\.\d{1,2}){1,2}$"#
    )

    static func shorten(_ text: String, to count: Int) -> String? {
        let cleaned = text.replacingOccurrences(of: "[^\\p{L}\\s&]", with: " ", options: .regularExpression)
        let words = cleaned.split(separator: " ").prefix(count)
        guard !words.isEmpty else { return nil }
        return PhraseExtractor.tidy(words.map(String.init))
    }

    /// "August 2026" or "08/2026" — never a bare month, because "may" and
    /// "march" are ordinary English words.
    static func monthYear(in text: String) -> String? {
        let months = [
            "january", "february", "march", "april", "may", "june", "july", "august",
            "september", "october", "november", "december",
        ]
        let lower = text.lowercased()

        // "August 2026" — the month has to be a word of its own, and a year
        // has to follow it.
        for month in months {
            let pattern = "(?i)\\b\(month)\\s*,?\\s*(20\\d{2})\\b"
            guard let range = lower.range(of: pattern, options: .regularExpression) else { continue }
            let year = lower[range].split(whereSeparator: { !$0.isNumber }).last.map(String.init) ?? ""
            return "\(month.prefix(3).capitalized) \(year)"
        }

        // "08/2026" and "2026/08".
        if let (monthPart, yearPart) = firstTwoCaptures(#"(\d{1,2})\s*[-/.]\s*(20\d{2})"#, in: text),
            let month = monthName(from: Int(monthPart) ?? 0, months: months)
        {
            return "\(month.prefix(3).capitalized) \(yearPart)"
        }
        if let (yearPart, monthPart) = firstTwoCaptures(#"(20\d{2})\s*[-/.]\s*(\d{1,2})"#, in: text),
            let month = monthName(from: Int(monthPart) ?? 0, months: months)
        {
            return "\(month.prefix(3).capitalized) \(yearPart)"
        }
        return nil
    }

    private static func monthName(from number: Int, months: [String]) -> String? {
        guard (1...12).contains(number) else { return nil }
        return months[number - 1]
    }

    private static func firstCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            match.numberOfRanges > 1, let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstTwoCaptures(_ pattern: String, in text: String) -> (String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            match.numberOfRanges > 2,
            let first = Range(match.range(at: 1), in: text),
            let second = Range(match.range(at: 2), in: text)
        else { return nil }
        return (String(text[first]), String(text[second]))
    }
}
