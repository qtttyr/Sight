import Foundation
import NaturalLanguage

/// Pulls short noun phrases ("hackathon rules", "аренда офиса") out of a line
/// of text with the system's linguistic tagger. It is offline, instant and
/// covers many languages, so naming never depends on a large model.
public enum PhraseExtractor {
    public static let maxWords = 3

    /// Candidate phrases of 1–3 words, best first (longer runs of content words first).
    public static func phrases(from line: String) -> [String] {
        let text = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 4 else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        var runs: [[String]] = []
        var current: [String] = []
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { tag, range in
            let word = String(text[range])
            let keeps = (tag == .noun || tag == .adjective)
                && word.contains(where: \.isLetter)
                && word.count >= 2
            if keeps {
                current.append(word)
            } else if !current.isEmpty {
                runs.append(current)
                current = []
            }
            return true
        }
        if !current.isEmpty { runs.append(current) }

        var phrases: [String] = []
        for run in runs {
            // The head noun sits at the end of a run, so keep the tail.
            let words = Array(run.suffix(maxWords))
            phrases.append(tidy(words))
        }
        return phrases
            .filter { $0.split(separator: " ").count >= 2 || $0.count >= 7 }
            .sorted { $0.split(separator: " ").count > $1.split(separator: " ").count }
    }

    /// "NOTION" → "Notion", first word capitalised, the rest left alone.
    static func tidy(_ words: [String]) -> String {
        let fixed = words.enumerated().map { index, word -> String in
            var value = word
            if value.count > 3, value == value.uppercased() { value = value.capitalized }
            if index == 0 { value = value.prefix(1).uppercased() + value.dropFirst() }
            return value
        }
        return fixed.joined(separator: " ")
    }
}
