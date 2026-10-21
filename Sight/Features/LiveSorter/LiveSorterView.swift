import SightCore
import SwiftUI

struct LiveSorterView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer(minLength: 28)
            DropZone(
                title: "Drop a folder",
                subtitle: "or click to choose the watched folder",
                height: 138,
                onTap: { model.chooseFolder() },
                onURLs: { model.handleDrop(urls: $0) }
            )
            Spacer(minLength: 24)
            metrics
            Spacer(minLength: 28)
            activity
            Spacer(minLength: 16)
        }
        .padding(.horizontal, 40)
        .padding(.top, 38)
        .padding(.bottom, 28)
        .sheet(isPresented: $model.isShowingReview) {
            ReviewView()
                .environment(model)
                .sightTheme(model.config.theme)
        }
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
            }
        }
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
                        model.isShowingReview = true
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
                    title: "Nothing sorted yet.",
                    subtitle: "Drop a folder, then sweep it. Files will appear here."
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
}
