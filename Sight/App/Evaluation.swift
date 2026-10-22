#if DEBUG
import AppKit
import CoreGraphics
import CoreText
import Foundation
import SightCore

/// Developer-only accuracy harness. Launch the debug build with `-SIGHT_EVAL`
/// and it measures the real classifier, with the real on-device model, on:
///
/// 1. `eval-corpus.json`: synthetic files (name, content, expected category)
///    that are written to a temp folder and classified.
/// 2. `eval-labels.json`: ground truth (file name → category) for files that
///    already sit in the watched folder, e.g. your real Downloads.
///
/// Both files live next to the app's config. The report is written to
/// `eval-report.txt` and the app exits, so the loop is scriptable.
struct EvalCase: Codable {
    let name: String
    let content: String?
    let expected: String
}

enum Evaluation {
    static var isEnabled: Bool { CommandLine.arguments.contains("-SIGHT_EVAL") }

    private static var directory: URL { AppPaths.applicationSupport }
    static var corpusURL: URL { directory.appendingPathComponent("eval-corpus.json") }
    static var labelsURL: URL { directory.appendingPathComponent("eval-labels.json") }
    static var reportURL: URL { directory.appendingPathComponent("eval-report.txt") }

    private struct Row {
        let name: String
        let expected: String
        let got: String
        let score: Float
        let accepted: Bool
        let reason: String
        let top: String
        let renamed: String?
        let decision: RoutingDecision
    }

    @MainActor
    static func run(model: AppModel) async {
        guard let sorter = model.sorter else { exit(2) }
        var report: [String] = []
        var config = model.config
        config.mode = .review
        // Evaluate the shipped defaults: Junk is opt-in and ships switched off.
        let rules = model.rules.map { rule -> CategoryRule in
            var copy = rule
            if copy.libraryID == "junk" { copy.isEnabled = false }
            return copy
        }

        // MARK: Synthetic corpus
        if let data = try? Data(contentsOf: corpusURL),
           let cases = try? JSONDecoder().decode([EvalCase].self, from: data) {
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("SightEval-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var written: [(URL, EvalCase)] = []
            for item in cases {
                let url = folder.appendingPathComponent(item.name)
                if write(item, to: url) { written.append((url, item)) }
            }

            report.append("== CORPUS (\(written.count) files, dimension \(config.dimension.rawValue), confidence \(config.confidence))")
            let rows = await classify(written.map { ($0.0, $0.1.expected) }, sorter: sorter, rules: rules, config: config)
            report += summarize(rows.filter { !$0.expected.hasPrefix("NEW:") })
            report += await folderReport(rows, sorter: sorter, rules: rules, config: config)
            report += renameReport(rows)

            if CommandLine.arguments.contains("-SIGHT_LEARN") {
                // Teach on every other file, measure on the rest.
                let byName = Dictionary(uniqueKeysWithValues: rules.map { ($0.name, $0) })
                var heldOut: [(URL, String)] = []
                for (index, pair) in written.enumerated() {
                    if index % 2 == 0, let rule = byName[pair.1.expected],
                       let file = try? FileSnapshot(url: pair.0) {
                        await sorter.learn(file: file, ruleID: rule.id)
                    } else {
                        heldOut.append((pair.0, pair.1.expected))
                    }
                }
                let before = ["(held-out, learned)"]
                let learnedRows = await classify(heldOut, sorter: sorter, rules: rules, config: config)
                report.append("")
                report.append("== LEARNING: \(before[0]) \(stats(learnedRows))")
                model.examples.reset()
                let baseRows = await classify(heldOut, sorter: sorter, rules: rules, config: config)
                report.append("== LEARNING: (held-out, no examples) \(stats(baseRows))")
                report += summarize(learnedRows).dropFirst(2)
            }

            if CommandLine.arguments.contains("-SIGHT_GRID") {
                report.append("")
                report.append("== TUNING GRID (corpus)  temp pool none → accuracy / accepted% / precision")
                for temperature in [Float(0.02), 0.03, 0.045] {
                    for pool in [1, 2, 3] {
                        for none in [Float(0.06), 0.1, 0.14, 0.18, 0.22] {
                            var tuning = ClassificationService.Tuning()
                            tuning.textTemperature = temperature
                            tuning.poolTop = pool
                            tuning.textNoneSimilarity = none
                            await sorter.setTuning(tuning)
                            let gridRows = await classify(written.map { ($0.0, $0.1.expected) }, sorter: sorter, rules: rules, config: config)
                            report.append(String(
                                format: "t=%.3f pool=%d none=%.2f → %@",
                                temperature, pool, none, stats(gridRows)
                            ))
                        }
                    }
                }
                await sorter.setTuning(ClassificationService.Tuning())
            }
            try? FileManager.default.removeItem(at: folder)
        } else {
            report.append("(no eval-corpus.json)")
        }

        // MARK: Real folder
        if let root = model.rootURL,
           let data = try? Data(contentsOf: labelsURL),
           let labels = try? JSONDecoder().decode([String: String].self, from: data) {
            let urls = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            let labelled = urls.compactMap { url -> (URL, String)? in
                guard let expected = labels[url.lastPathComponent] else { return nil }
                return (url, expected)
            }
            report.append("")
            report.append("== REAL FOLDER \(root.path) (\(labelled.count) labelled of \(urls.count))")
            let rows = await classify(labelled, sorter: sorter, rules: rules, config: config)
            report += summarize(rows)
            report += renameReport(rows)
        }

        try? report.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)
        exit(0)
    }

    // MARK: - Naming and folders

    private static func renameReport(_ rows: [Row]) -> [String] {
        let renamed = rows.filter { $0.renamed != nil }
        var lines = ["", "-- renames (\(renamed.count) of \(rows.count)) --"]
        for row in renamed { lines.append("\(row.name)  →  \(row.renamed ?? "")") }
        return lines
    }

    private static func folderReport(
        _ rows: [Row], sorter: Sorter, rules: [CategoryRule], config: SightConfig
    ) async -> [String] {
        let all = rows.map(\.decision)
        let leftovers = AppModel.discoveryCandidates(all, proposals: all)
        let expected = Dictionary(uniqueKeysWithValues: rows.map { ($0.decision.id, $0.expected) })
        var lines = ["", "-- folder discovery: \(leftovers.count) leftovers --"]
        for item in leftovers {
            lines.append("  leftover \(item.file.name) [\(expected[item.id] ?? "")] p=\(String(format: "%.2f", item.score))")
        }
        for row in rows where row.expected.hasPrefix("NEW:") {
            lines.append("  new-topic \(row.name) → \(row.got) p=\(String(format: "%.2f", row.score)) \(row.accepted ? "ACCEPTED" : "")")
        }
        let suggestions = await sorter.discoverFolders(leftovers: leftovers, rules: rules, config: config)
        for suggestion in suggestions {
            let members = suggestion.decisions.map { expected[$0.id] ?? "?" }
            lines.append("  ➜ SUGGEST “\(suggestion.name)” \(suggestion.count) files coh=\(String(format: "%.2f", suggestion.coherence)) [\(suggestion.evidence)] members=\(members.joined(separator: ","))")
        }
        if suggestions.isEmpty { lines.append("  (no suggestions)") }
        return lines
    }

    // MARK: - Running

    private static func classify(
        _ items: [(URL, String)],
        sorter: Sorter,
        rules: [CategoryRule],
        config: SightConfig
    ) async -> [Row] {
        var rows: [Row] = []
        for (url, expected) in items {
            guard let file = try? FileSnapshot(url: url),
                  let decision = try? await sorter.classify(file: file, rules: rules, config: config)
            else { continue }
            let top = decision.ranking.prefix(3)
                .map { "\($0.name) \(String(format: "%.2f", $0.score))" }
                .joined(separator: " | ")
            rows.append(Row(
                name: url.lastPathComponent,
                expected: expected,
                got: decision.rule?.name ?? "-",
                score: decision.score,
                accepted: decision.accepted,
                reason: decision.reason ?? "",
                top: top,
                renamed: decision.suggestedName,
                decision: decision
            ))
        }
        return rows
    }

    private static func stats(_ rows: [Row]) -> String {
        guard !rows.isEmpty else { return "no rows" }
        let correct = rows.filter { $0.got == $0.expected }.count
        let accepted = rows.filter(\.accepted)
        let acceptedCorrect = accepted.filter { $0.got == $0.expected }.count
        return String(
            format: "acc %.1f%%  accepted %.1f%%  precision %.1f%%  wrong-accepted %d",
            100 * Double(correct) / Double(rows.count),
            100 * Double(accepted.count) / Double(rows.count),
            accepted.isEmpty ? 0 : 100 * Double(acceptedCorrect) / Double(accepted.count),
            accepted.count - acceptedCorrect
        )
    }

    private static func summarize(_ rows: [Row]) -> [String] {
        var lines = [stats(rows), ""]
        let wrong = rows.filter { $0.got != $0.expected }
        lines.append("-- misses (\(wrong.count)) --")
        for row in wrong.sorted(by: { $0.score > $1.score }) {
            lines.append("✗ \(row.name)  expected=\(row.expected) got=\(row.got) p=\(String(format: "%.2f", row.score)) \(row.accepted ? "ACCEPTED" : "review")  [\(row.top)]  \(row.reason)")
        }
        let doubtful = rows.filter { $0.got == $0.expected && !$0.accepted }
        lines.append("")
        lines.append("-- right but not confident (\(doubtful.count)) --")
        for row in doubtful {
            lines.append("~ \(row.name)  \(row.got) p=\(String(format: "%.2f", row.score))  [\(row.top)]")
        }
        return lines
    }

    // MARK: - Writing synthetic files

    private static func write(_ item: EvalCase, to url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let text = item.content ?? ""
        switch ext {
        case "pdf":
            return writePDF(text: text, to: url)
        case "docx", "rtf":
            let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 12)])
            let type: NSAttributedString.DocumentType = ext == "docx" ? .officeOpenXML : .rtf
            guard let data = try? attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: type]
            ) else { return false }
            return (try? data.write(to: url)) != nil
        case "png":
            return writeScreenPNG(to: url)
        case "mp4", "mov", "mkv", "mp3", "wav", "m4a", "flac", "zip", "dmg", "gz", "tgz", "pkg", "7z", "rar", "psd", "ai", "fig", "sketch", "ttf", "otf", "xlsx", "pptx", "key", "numbers", "pages", "gguf", "heic":
            return (try? Data(repeating: 0x41, count: 2048).write(to: url)) != nil
        default:
            return (try? text.write(to: url, atomically: true, encoding: .utf8)) != nil
        }
    }

    private static func writePDF(text: String, to url: URL) -> Bool {
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        guard let context = CGContext(url as CFURL, mediaBox: &box, nil) else { return false }
        context.beginPDFPage(nil)
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: CTFontCreateWithName("Helvetica" as CFString, 12, nil)]
        )
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: box.insetBy(dx: 48, dy: 48), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        CTFrameDraw(frame, context)
        context.endPDFPage()
        context.closePDF()
        return true
    }

    /// A plain 1170×2532 PNG: the size of an iPhone screen, no metadata.
    private static func writeScreenPNG(to url: URL) -> Bool {
        let width = 1170, height = 2532
        guard let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage() else { return false }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: url)) != nil
    }
}
#endif
