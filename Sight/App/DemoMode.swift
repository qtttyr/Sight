#if DEBUG
    import Foundation
    import SightCore

    /// A deterministic, offline state used by UI tests and screenshots. It is
    /// compiled only in debug builds and only activates with the `-SightDemo`
    /// launch argument.
    enum DemoMode {
        static var isEnabled: Bool {
            ProcessInfo.processInfo.arguments.contains("-SightDemo")
        }

        @MainActor
        static func configure(_ model: AppModel) {
            let root = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Downloads", isDirectory: true)
                .appendingPathComponent("Sight Demo", isDirectory: true)
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

            let rules = makeRules(root: root)
            model.isDemoMode = true
            model.config = SightConfig(
                rootPath: root.path,
                mode: .review,
                dimension: .compact,
                theme: .dark,
                loadVision: true,
                loadAudio: false,
                hasCompletedOnboarding: true,
                autoSortEnabled: false
            )
            model.rootURL = root
            model.rules = rules
            model.events = makeEvents()
            model.pendingDecisions = makePendingDecisions(root: root, rules: rules)
            model.modelState = .ready
            model.modelDiskUsage = ModelManifest.totalBytes(for: [.text, .vision])
            model.isBootstrapping = false

            for (index, rule) in rules.enumerated() {
                let phase = Float(index) * 0.7
                let vector = (0..<256).map { index in
                    sin(Float(index) * 0.11 + phase) + cos(Float(index) * 0.037 + phase)
                }
                model.ruleFingerprints[rule.id] = VectorMath.fingerprint(vector, bins: 48)
            }
        }

        private static func makeRules(root: URL) -> [CategoryRule] {
            [
                CategoryRule(
                    name: "Finance",
                    prompt: "Invoices, receipts, bank statements, tax documents, and anything about money.",
                    destination: root.appendingPathComponent("Finance", isDirectory: true)
                ),
                CategoryRule(
                    name: "Work",
                    prompt: "Contracts, reports, strategy documents, meeting notes, and client work.",
                    destination: root.appendingPathComponent("Work", isDirectory: true)
                ),
                CategoryRule(
                    name: "Images",
                    prompt: "Photos, screenshots, design exports, and visual references.",
                    destination: root.appendingPathComponent("Images", isDirectory: true)
                ),
                CategoryRule(
                    name: "Writing",
                    prompt: "Drafts, essays, blog posts, and long-form notes.",
                    destination: root.appendingPathComponent("Writing", isDirectory: true)
                ),
                CategoryRule(
                    name: "Design",
                    prompt: "Design files, mockups, brand assets, and product specs.",
                    destination: root.appendingPathComponent("Design", isDirectory: true)
                ),
            ]
        }

        private static func makeEvents() -> [SortEvent] {
            let now = Date.now
            return [
                SortEvent(
                    date: now.addingTimeInterval(-60), fileName: "Invoice_Acme_March.pdf", category: "Finance",
                    score: 0.94, outcome: .moved),
                SortEvent(
                    date: now.addingTimeInterval(-180), fileName: "Screenshot 2026-10-21 at 13.02.36.png",
                    category: "Images", score: 0.91, outcome: .moved),
                SortEvent(
                    date: now.addingTimeInterval(-240), fileName: "Q4_Strategy.docx", category: "Work", score: 0.49,
                    outcome: .review),
                SortEvent(
                    date: now.addingTimeInterval(-400), fileName: "IMG_4821.HEIC", category: "Images", score: 0.88,
                    outcome: .moved),
                SortEvent(
                    date: now.addingTimeInterval(-520), fileName: "receipt_uber.pdf", category: "Finance", score: 0.82,
                    outcome: .moved),
                SortEvent(
                    date: now.addingTimeInterval(-700), fileName: "draft_blog.md", category: "Writing", score: 0.44,
                    outcome: .review),
                SortEvent(
                    date: now.addingTimeInterval(-840), fileName: "random_notes.txt", category: nil, score: nil,
                    outcome: .unrecognized),
                SortEvent(
                    date: now.addingTimeInterval(-980), fileName: "Design_System.fig", category: "Design", score: 0.86,
                    outcome: .moved),
                SortEvent(
                    date: now.addingTimeInterval(-1200), fileName: "tax_return_2025.pdf", category: "Finance",
                    score: 0.53, outcome: .review),
                SortEvent(
                    date: now.addingTimeInterval(-1500), fileName: "family_trip.jpg", category: "Images", score: 0.79,
                    outcome: .moved),
                SortEvent(
                    date: now.addingTimeInterval(-1800), fileName: "contract_final.pdf", category: "Work", score: 0.90,
                    outcome: .moved),
                SortEvent(
                    date: now.addingTimeInterval(-2100), fileName: "voice_memo.m4a", category: nil, score: nil,
                    outcome: .unrecognized),
            ]
        }

        private static func makePendingDecisions(root: URL, rules: [CategoryRule]) -> [RoutingDecision] {
            guard rules.count >= 3 else { return [] }
            let work = rules[1]
            let writing = rules[3]
            let finance = rules[0]

            return [
                RoutingDecision(
                    file: FileSnapshot(name: "Q4_Strategy.docx", url: root.appendingPathComponent("Q4_Strategy.docx")),
                    rule: work,
                    score: 0.49,
                    runnerUp: 0.44,
                    accepted: false,
                    ranking: [
                        (work.id, work.name, 0.49),
                        (finance.id, finance.name, 0.44),
                        (writing.id, writing.name, 0.31),
                    ]
                ),
                RoutingDecision(
                    file: FileSnapshot(name: "draft_blog.md", url: root.appendingPathComponent("draft_blog.md")),
                    rule: writing,
                    score: 0.44,
                    runnerUp: 0.41,
                    accepted: false,
                    ranking: [
                        (writing.id, writing.name, 0.44),
                        (work.id, work.name, 0.41),
                        (finance.id, finance.name, 0.22),
                    ]
                ),
                RoutingDecision(
                    file: FileSnapshot(
                        name: "tax_return_2025.pdf", url: root.appendingPathComponent("tax_return_2025.pdf")),
                    rule: finance,
                    score: 0.53,
                    runnerUp: 0.48,
                    accepted: false,
                    ranking: [
                        (finance.id, finance.name, 0.53),
                        (work.id, work.name, 0.48),
                        (writing.id, writing.name, 0.19),
                    ]
                ),
            ]
        }
    }
#endif
