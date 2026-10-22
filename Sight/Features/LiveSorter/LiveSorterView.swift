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
                    .foregroundStyle(theme.textFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            HStack(spacing: 8) {
                modeToggle
                Button {
                    Task { await model.runSweep() }
                } label: {
                    Text("Sweep")
                }
                .buttonStyle(SightButtonStyle(kind: .primary))
                .disabled(!model.modelState.isReady || model.rootURL == nil || model.isSweeping)

                SightIconButton(systemName: "arrow.uturn.backward", help: "Undo last move") {
                    Task { await model.undoLastMove() }
                }
            }
            .padding(.top, 6)
        }
    }

    private var statusTitle: String {
        if model.isSweeping { return "Sorting" }
        if model.modelState.isReady, model.rootURL != nil { return "Watching" }
        return "Idle"
    }

    private var modeToggle: some View {
        HStack(spacing: 2) {
            modeButton("REVIEW", mode: .review)
            modeButton("AUTO", mode: .auto)
        }
        .padding(2)
        .background(theme.hover)
        .clipShape(Capsule())
    }

    private func modeButton(_ title: String, mode: SortMode) -> some View {
        let isActive = model.config.mode == mode
        return Button {
            withAnimation(SightMotion.quick) {
                model.config.mode = mode
                model.config.autoSortEnabled = mode == .auto
                model.saveConfig()
            }
        } label: {
            Text(title)
                .font(SightFont.micro())
                .tracking(0.08)
                .foregroundStyle(isActive ? theme.buttonLabel : theme.textTertiary)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background {
                    if isActive { Capsule().fill(theme.buttonFill) }
                }
        }
        .buttonStyle(.plain)
        .help(mode == .review
            ? "Nothing moves without your approval."
            : "Confident files are sorted silently.")
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
                    Text(pointer)
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

    private var pointer: String {
        guard let summary = model.lastSummary else { return "" }
        var parts: [String] = []
        if summary.skipped > 0 { parts.append("\(summary.skipped) already handled, from memory") }
        if !summary.events.isEmpty {
            parts.append("\(summary.events.count) freshly analyzed")
        } else if summary.skipped > 0 {
            parts.append("nothing changed since the last sweep")
        }
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
        let contents = (try? FileManager.default.contentsOfDirectory(
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
