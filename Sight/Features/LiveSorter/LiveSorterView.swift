import SightCore
import SwiftUI

struct LiveSorterView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme

    @State private var topLevelCount = 0

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 24)
            if model.rootURL == nil {
                DropZone(
                    title: "Drop a folder",
                    subtitle: "or click to choose the watched folder",
                    height: 138,
                    onTap: { model.chooseFolder() },
                    onURLs: { model.handleDrop(urls: $0) }
                )
                Spacer(minLength: 24)
            } else {
                RootOverview(
                    url: model.rootURL!,
                    fileCount: topLevelCount,
                    onChangeFolder: { model.chooseFolder() }
                )
                .task(id: model.rootURL) {
                    topLevelCount = Self.countTopLevel(at: model.rootURL)
                }
                Spacer(minLength: 20)
            }
            metrics
            if !model.folderSuggestions.isEmpty {
                Spacer(minLength: 18)
                VStack(spacing: 10) {
                    ForEach(model.folderSuggestions) { suggestion in
                        FolderSuggestionCard(suggestion: suggestion)
                    }
                }
            }
            Spacer(minLength: 24)
            activity
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 40)
        .padding(.top, 38)
        .padding(.bottom, 28)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    LiveDot(isActive: model.modelState.isReady && model.rootURL != nil)
                    Text("LIVE SORTER")
                        .font(SightFont.micro())
                        .tracking(0.18)
                        .foregroundStyle(theme.textTertiary)
                }
                Text(statusTitle)
                    .font(.system(size: 38, weight: .semibold))
                    .tracking(-0.02)
                    .foregroundStyle(theme.textPrimary)
                Text(model.rootDisplayPath)
                    .font(SightFont.mono())
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                statusNote
            }

            Spacer()

            HStack(spacing: 8) {
                modeToggle
                Button {
                    Task { await model.runSweepWithFeedback() }
                } label: {
                    Text("Sweep")
                }
                .buttonStyle(SightButtonStyle(kind: .primary))
                .disabled(!model.modelState.isReady || model.rootURL == nil || model.isSweeping)
                .help(
                    model.modelState.isReady
                        ? "Sort everything in the watched folder."
                        : "Sight needs the local model first. Open Settings to download it.")

                SightIconButton(systemName: "arrow.uturn.backward", help: "Undo the last sort (the whole batch)") {
                    Task { await model.undoLastMove() }
                }
                .disabled(model.events.isEmpty)
            }
            .padding(.top, 6)
        }
    }

    private var statusTitle: String {
        if model.isSweeping { return "Sorting" }
        if case .failed = model.modelState { return "Model Error" }
        if model.modelState.isReady, model.rootURL != nil { return "Watching" }
        return "Idle"
    }

    /// Why Sight is not working, in plain words. Without this the user sees a
    /// disabled button and no explanation at all.
    @ViewBuilder
    private var statusNote: some View {
        if case .failed(let message) = model.modelState {
            Text(message)
                .font(SightFont.micro())
                .foregroundStyle(theme.textTertiary)
                .lineLimit(2)
                .help("Open Settings to download the model again.")
        } else if !model.modelState.isReady {
            Text("The local model is not ready yet — open Settings to download it.")
                .font(SightFont.micro())
                .foregroundStyle(theme.textTertiary)
                .lineLimit(2)
        }
    }

    private var modeToggle: some View {
        SightSegmented(
            options: [
                SightSegment(id: SortMode.review, label: "REVIEW"),
                SightSegment(id: SortMode.auto, label: "AUTO"),
            ],
            selection: Binding(
                get: { model.config.mode },
                set: { mode in
                    model.config.mode = mode
                    model.config.autoSortEnabled = mode == .auto
                    model.saveConfig()
                }
            ),
            label: "Sorting mode"
        )
        .help(
            model.config.mode == .auto
                ? "Confident files are sorted silently."
                : "Nothing moves without your approval.")
    }

    private var metrics: some View {
        VStack(spacing: 14) {
            HStack(spacing: 24) {
                MetricView(value: "\(model.events.count)", label: "PROCESSED")
                MetricView(value: "\(movedCount)", label: "MOVED")
                MetricView(value: "\(model.pendingDecisions.count)", label: "REVIEW")
                MetricView(value: "\(model.rules.count)", label: "RULES")
            }
            if let progress = model.sortProgress {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(progress.currentName)
                            .font(SightFont.micro())
                            .foregroundStyle(theme.textTertiary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(progress.processed) / \(progress.total)")
                            .font(SightFont.micro())
                            .foregroundStyle(theme.textFaint)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(theme.line).frame(height: 2)
                            Capsule()
                                .fill(theme.paper)
                                .frame(
                                    width: max(2, proxy.size.width * progressFraction(progress)),
                                    height: 2
                                )
                        }
                    }
                    .frame(height: 2)
                }
            } else if let summary = model.lastSummary, !model.isSweeping {
                HStack(spacing: 8) {
                    Text(pointer(for: summary))
                        .font(SightFont.micro())
                        .foregroundStyle(theme.textFaint)
                    Spacer()
                    if !model.pendingDecisions.isEmpty {
                        Button {
                            model.activeSheet = .review
                        } label: {
                            Text("Review \(model.pendingDecisions.count)")
                                .font(SightFont.micro())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.textSecondary)
                        .help("Open the review queue.")
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    private func pointer(for summary: SortSummary) -> String {
        var parts: [String] = []
        if summary.moved > 0 { parts.append("\(summary.moved) sorted") }
        if summary.review > 0 { parts.append("\(summary.review) waiting for your OK") }
        if summary.failed > 0 { parts.append("\(summary.failed) failed") }
        if summary.moved == 0, summary.review == 0, summary.failed == 0 {
            parts.append("nothing to sort")
        }
        if summary.skipped > 0 { parts.append("\(summary.skipped) from memory") }
        let seconds =
            Double(summary.duration.components.seconds)
            + Double(summary.duration.components.attoseconds) / 1e18
        parts.append(String(format: "%.1fs", seconds))
        return parts.joined(separator: " · ")
    }

    private var movedCount: Int {
        model.events.filter { $0.outcome == .moved }.count
    }

    private func progressFraction(_ progress: SortProgress) -> CGFloat {
        guard progress.total > 0 else { return 0 }
        return CGFloat(progress.processed) / CGFloat(progress.total)
    }

    @ViewBuilder
    private var activity: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionHeader(title: "ACTIVITY")
                Spacer()
                if !model.pendingDecisions.isEmpty {
                    Button {
                        model.activeSheet = .review
                    } label: {
                        HStack(spacing: 8) {
                            Text("Review \(model.pendingDecisions.count)")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                    .buttonStyle(SightButtonStyle(kind: .ghost))
                }
            }

            if model.events.isEmpty {
                EmptyState(
                    icon: "tray",
                    title: model.rules.isEmpty ? "Rules first." : "Ready to sweep.",
                    subtitle: model.rules.isEmpty
                        ? "Open Rules and add categories — then Sweep makes proposals, and nothing moves without your review."
                        : "Press Sweep. Every file gets a proposal in Review, and you approve what moves."
                )
                .frame(minHeight: 180)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(model.events.prefix(14))) { event in
                            EventRow(event: event)
                            Hairline()
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 300)
            }
        }
    }

    private static func countTopLevel(at url: URL?) -> Int {
        guard let url else { return 0 }
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
                options: []
            )) ?? []
        let regular = contents.filter { item in
            let values = try? item.resourceValues(forKeys: [.isRegularFileKey, .isHiddenKey])
            return (values?.isRegularFile ?? false) && !(values?.isHidden ?? false)
        }
        return regular.count
    }
}

/// The compact "this folder is being watched" card. Replaces the empty drop
/// zone once a root exists: the folder, its size and an inline way to change it.
private struct RootOverview: View {
    @Environment(\.sightTheme) private var theme
    let url: URL
    let fileCount: Int
    let onChangeFolder: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "folder")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(fileCount) files at top level")
                    .font(SightFont.headline())
                    .foregroundStyle(theme.textPrimary)
                Text("Subfolders are never entered. Drop new files in and Sight will propose a place.")
                    .font(SightFont.body())
                    .foregroundStyle(theme.textFaint)
                    .lineLimit(1)
            }

            Spacer()

            Button("Change Folder") {
                onChangeFolder()
            }
            .buttonStyle(SightButtonStyle(kind: .ghost))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .overlay {
            RoundedRectangle(cornerRadius: SightRadius.card)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                .foregroundStyle(theme.line)
        }
    }
}

/// "7 files fit no folder but belong together — create one?"
private struct FolderSuggestionCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    let suggestion: FolderSuggestion

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 15))
                .foregroundStyle(theme.textSecondary)

            VStack(alignment: .leading, spacing: 3) {
                Text("New folder: \(suggestion.name)")
                    .font(SightFont.headline())
                    .foregroundStyle(theme.textPrimary)
                Text("\(suggestion.count) files fit no category but clearly belong together — \(examples)")
                    .font(SightFont.body())
                    .foregroundStyle(theme.textFaint)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Button("Not now") { model.dismissSuggestion(suggestion) }
                .buttonStyle(SightButtonStyle(kind: .ghost))
            Button("Create & sort") {
                Task { await model.acceptSuggestion(suggestion) }
            }
            .buttonStyle(SightButtonStyle(kind: .primary))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .overlay {
            RoundedRectangle(cornerRadius: SightRadius.card)
                .strokeBorder(theme.lineStrong, lineWidth: 1)
        }
    }

    private var examples: String {
        suggestion.decisions.prefix(3).map { $0.suggestedName ?? $0.file.name }.joined(separator: ", ")
    }
}
