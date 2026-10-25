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
        static var isBenchmarkEnabled: Bool { CommandLine.arguments.contains("-SIGHT_BENCH") }

        /// Unbuffered output, so the last line survives a crash.
        private static func log(_ text: String) {
            FileHandle.standardError.write(Data((text + "\n").utf8))
        }

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
                let cases = try? JSONDecoder().decode([EvalCase].self, from: data)
            {
                let folder = FileManager.default.temporaryDirectory
                    .appendingPathComponent("SightEval-\(UUID().uuidString)", isDirectory: true)
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                var written: [(URL, EvalCase)] = []
                for item in cases {
                    let url = folder.appendingPathComponent(item.name)
                    if write(item, to: url) { written.append((url, item)) }
                }

                report.append(
                    "== CORPUS (\(written.count) files, dimension \(config.dimension.rawValue), confidence \(config.confidence))"
                )
                let rows = await classify(
                    written.map { ($0.0, $0.1.expected) }, sorter: sorter, rules: rules, config: config)
                report += summarize(rows.filter { !$0.expected.hasPrefix("NEW:") })
                report += await folderReport(rows, sorter: sorter, rules: rules, config: config)
                report += renameReport(rows)
                report += await timingReport(sorter: sorter, files: written.count)

                if CommandLine.arguments.contains("-SIGHT_LEARN") {
                    // Teach on every other file, measure on the rest.
                    let byName = Dictionary(uniqueKeysWithValues: rules.map { ($0.name, $0) })
                    var heldOut: [(URL, String)] = []
                    for (index, pair) in written.enumerated() {
                        if index % 2 == 0, let rule = byName[pair.1.expected],
                            let file = try? FileSnapshot(url: pair.0)
                        {
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
                                let gridRows = await classify(
                                    written.map { ($0.0, $0.1.expected) }, sorter: sorter, rules: rules, config: config)
                                report.append(
                                    String(
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
                let labels = try? JSONDecoder().decode([String: String].self, from: data)
            {
                let urls =
                    (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
                let labelled = urls.compactMap { url -> (URL, String)? in
                    guard let expected = labels[url.lastPathComponent] else { return nil }
                    return (url, expected)
                }
                report.append("")
                report.append("== REAL FOLDER \(root.path) (\(labelled.count) labelled of \(urls.count))")
                let rows = await classify(labelled, sorter: sorter, rules: rules, config: config)
                report += summarize(rows)
                report += renameReport(rows)
                report += await timingReport(sorter: sorter, files: labelled.count)
            }

            try? report.joined(separator: "\n").write(to: reportURL, atomically: true, encoding: .utf8)
            exit(0)
        }

        // MARK: - Naming and folders

        /// Times the parts of the vision pipeline. The whole sweep is only as
        /// fast as its slowest stage, and nobody can tell which one that is
        /// without measuring.
        static func runBenchmark(model: AppModel) async {
            guard let provider = await model.embeddingProvider else {
                print("BENCH: no provider")
                return
            }
            let folder = FileManager.default.temporaryDirectory
                .appendingPathComponent("SightBench-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

            let screenshot = folder.appendingPathComponent("screenshot.png")
            let photo = folder.appendingPathComponent("photo.jpg")
            _ = writeScreenPNG(to: screenshot)
            _ = writeJPEG(to: photo, width: 4032, height: 3024)

            for (label, url) in [("screenshot 1170x2532", screenshot), ("photo 4032x3024", photo)] {
                guard FileManager.default.fileExists(atPath: url.path) else { continue }
                await benchOne(label: label, url: url, provider: provider)
            }

            // Real pictures from a folder, when the user names one.
            if CommandLine.arguments.count > 2 {
                let folder = URL(fileURLWithPath: CommandLine.arguments[2])
                let files =
                    (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
                let images = files.filter {
                    ["png", "jpg", "jpeg", "heic", "webp", "tiff"].contains($0.pathExtension.lowercased())
                }
                log("BENCH folder \(folder.lastPathComponent): \(images.count) pictures")

                var exact = ContinuousClock.now
                for file in images {
                    _ = try? await provider.embedExact(imageAt: file)
                }
                let exactTime = (ContinuousClock.now - exact).seconds

                var fast = ContinuousClock.now
                for file in images {
                    _ = try? await provider.embed(imageAt: file)
                }
                let fastTime = (ContinuousClock.now - fast).seconds

                log(
                    """
                    BENCH folder total
                      exact (vendored resizer)      \(String(format: "%.2f", exactTime))s
                      fast  (ImageIO + CoreGraphics) \(String(format: "%.2f", fastTime))s
                      speedup \(String(format: "%.1f", exactTime / max(fastTime, 0.001)))x
                    """)
            }
            try? FileManager.default.removeItem(at: folder)
        }

        private static func benchOne(label: String, url: URL, provider: CoreAIEmbeddingProvider) async {
            let decoding = ContinuousClock.now
            let decoded = try? ImageDecoder.decodeRGB(url: url, applyEXIFOrientation: true)
            let decodeTime = (ContinuousClock.now - decoding).seconds

            var resizeTime: TimeInterval = 0
            var patchTime: TimeInterval = 0
            var inputSize = "?"
            if let decoded {
                let resizing = ContinuousClock.now
                let resized = try? ImagePreprocessor.resized(decoded)
                resizeTime = (ContinuousClock.now - resizing).seconds
                if let resized {
                    inputSize = "\(resized.width)x\(resized.height)"
                    let patching = ContinuousClock.now
                    _ = ImagePreprocessor.patchify(
                        resizedRGB: resized.rgb, width: resized.width, height: resized.height)
                    patchTime = (ContinuousClock.now - patching).seconds
                }
            }

            // The same picture, prepared the fast way. The model cannot tell
            // the difference — the cosine says so.
            let fastStarted = ContinuousClock.now
            var fastVector: [Float]?
            do {
                let inputs = try ImagePreparation.inputs(for: url)
                fastVector = try await provider.embed(prepared: inputs)
            } catch {
                log("BENCH fast path failed: \(error)")
            }
            let fastTime = (ContinuousClock.now - fastStarted).seconds

            let inferring = ContinuousClock.now
            let vector = try? await provider.embed(imageAt: url)
            let inferTime = (ContinuousClock.now - inferring).seconds

            var agreement = "n/a"
            if let vector, let fastVector, vector.count == fastVector.count {
                let similarity = zip(vector, fastVector).reduce(0.0) { sum, pair in
                    sum + Double(pair.0) * Double(pair.1)
                }
                agreement = String(format: "cosine %.5f", similarity)
            }

            func seconds(_ value: TimeInterval) -> String { String(format: "%.3f", value) }
            log(
                """
                BENCH \(label) → \(inputSize)
                  vendored  \(seconds(inferTime))s  (decode \(seconds(decodeTime)) + resize \(seconds(resizeTime)) + patch \(seconds(patchTime)) + model)
                  FAST      \(seconds(fastTime))s  (\(agreement))
                """)
        }

        /// Where the time went. Performance work needs numbers, not guesses.
        private static func timingReport(sorter: Sorter, files: Int) async -> [String] {
            let t = await sorter.timings
            let total = t.total
            guard total > 0, files > 0 else { return [] }
            func share(_ value: TimeInterval) -> String {
                String(format: "%5.1f%%", 100 * value / total)
            }
            func line(_ label: String, _ value: TimeInterval) -> String {
                String(format: "  %-14@ %6.2fs  %@", label as NSString, value, share(value))
            }
            return [
                "",
                "-- time (\(files) files, \(String(format: "%.2f", total))s total, \(String(format: "%.0f", total / Double(files) * 1000))ms/file) --",
                line("read+parse", t.extract),
                line("text model", t.textEmbed),
                line("vision model", t.imageEmbed),
                line("compare", t.compare),
                line("learned", t.learned),
                line("naming+ocr", t.naming),
                line("move", t.moving),
                line("discovery", t.discovery),
            ]
        }

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
                lines.append(
                    "  leftover \(item.file.name) [\(expected[item.id] ?? "")] p=\(String(format: "%.2f", item.score))")
            }
            for row in rows where row.expected.hasPrefix("NEW:") {
                lines.append(
                    "  new-topic \(row.name) → \(row.got) p=\(String(format: "%.2f", row.score)) \(row.accepted ? "ACCEPTED" : "")"
                )
            }
            let suggestions = await sorter.discoverFolders(leftovers: leftovers, rules: rules, config: config)
            for suggestion in suggestions {
                let members = suggestion.decisions.map { expected[$0.id] ?? "?" }
                lines.append(
                    "  ➜ SUGGEST “\(suggestion.name)” \(suggestion.count) files coh=\(String(format: "%.2f", suggestion.coherence)) [\(suggestion.evidence)] members=\(members.joined(separator: ","))"
                )
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
                rows.append(
                    Row(
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
                lines.append(
                    "✗ \(row.name)  expected=\(row.expected) got=\(row.got) p=\(String(format: "%.2f", row.score)) \(row.accepted ? "ACCEPTED" : "review")  [\(row.top)]  \(row.reason)"
                )
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
                guard
                    let data = try? attributed.data(
                        from: NSRange(location: 0, length: attributed.length),
                        documentAttributes: [.documentType: type]
                    )
                else { return false }
                return (try? data.write(to: url)) != nil
            case "png":
                return writeScreenPNG(to: url)
            case "mp4", "mov", "mkv", "mp3", "wav", "m4a", "flac", "zip", "dmg", "gz", "tgz", "pkg", "7z", "rar", "psd",
                "ai", "fig", "sketch", "ttf", "otf", "xlsx", "pptx", "key", "numbers", "pages", "gguf", "heic":
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
            guard
                let context = CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }
            context.setFillColor(CGColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            guard let image = context.makeImage() else { return false }
            let rep = NSBitmapImageRep(cgImage: image)
            guard let data = rep.representation(using: .png, properties: [:]) else { return false }
            return (try? data.write(to: url)) != nil
        }

        /// A camera-sized JPEG: the other half of what people sort.
        private static func writeJPEG(to url: URL, width: Int, height: Int) -> Bool {
            guard
                let context = CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return false }
            for index in 0..<12 {
                context.setFillColor(
                    CGColor(
                        red: 0.2 + 0.6 * Double(index % 3) / 3,
                        green: 0.3 + 0.5 * Double(index % 4) / 4,
                        blue: 0.4 + 0.5 * Double(index % 5) / 5,
                        alpha: 1))
                context.fill(CGRect(x: index * 300, y: index * 200, width: 900, height: 700))
            }
            guard let image = context.makeImage() else { return false }
            let rep = NSBitmapImageRep(cgImage: image)
            guard let data = rep.representation(using: .jpeg, properties: [:]) else { return false }
            return (try? data.write(to: url)) != nil
        }
    }
#endif
