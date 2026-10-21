import SightCore
import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme

    @State private var step = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            theme.ink.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                Spacer(minLength: 48)

                Group {
                    switch step {
                    case 0: welcome
                    case 1: folderStep
                    default: modelStep
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .transition(.opacity.combined(with: .move(edge: .trailing)))

                Spacer()
                footer
            }
            .padding(.horizontal, 64)
            .padding(.top, 72)
            .padding(.bottom, 40)
        }
        .onChange(of: model.rootURL) { _, newValue in
            if newValue != nil, step == 1 {
                withAnimation(SightMotion.spring) { step = 2 }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Circle().fill(theme.paper).frame(width: 8, height: 8)
            Text("SIGHT")
                .font(SightFont.micro())
                .tracking(0.3)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? theme.paper : theme.lineStrong)
                        .frame(width: index == step ? 20 : 6, height: 3)
                        .animation(SightMotion.spring, value: step)
                }
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("Your files,\nsorted by meaning.")
                .font(.system(size: 54, weight: .semibold))
                .tracking(-0.03)
                .foregroundStyle(theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("On-device. Private. Instant.")
                .font(SightFont.body())
                .foregroundStyle(theme.textSecondary)

            Button("Begin") {
                withAnimation(SightMotion.spring) { step = 1 }
            }
            .buttonStyle(SightButtonStyle(kind: .primary))
            .padding(.top, 12)
        }
    }

    private var folderStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            SectionHeader(title: "01 / FOLDER", subtitle: "Where should Sight look?")

            HStack(spacing: 12) {
                Text(model.rootDisplayPath)
                    .font(SightFont.mono())
                    .foregroundStyle(model.rootURL == nil ? theme.textFaint : theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Choose Folder") {
                    model.chooseFolder()
                }
                .buttonStyle(SightButtonStyle(kind: .ghost))

                Button("Use Downloads") {
                    let downloads = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent("Downloads", isDirectory: true)
                    model.setRoot(downloads)
                }
                .buttonStyle(SightButtonStyle(kind: .primary))
            }

            Hairline()

            VStack(alignment: .leading, spacing: 12) {
                Text("STARTER RULES")
                    .font(SightFont.micro())
                    .tracking(0.14)
                    .foregroundStyle(theme.textFaint)

                if model.rules.isEmpty {
                    Text("Choose a folder and Sight will create four editable rules.")
                        .font(SightFont.body())
                        .foregroundStyle(theme.textTertiary)
                } else {
                    ForEach(model.rules) { rule in
                        HStack(alignment: .top, spacing: 14) {
                            Text(rule.name)
                                .font(SightFont.label())
                                .foregroundStyle(theme.textPrimary)
                                .frame(width: 70, alignment: .leading)
                            Text(rule.prompt)
                                .font(SightFont.body())
                                .foregroundStyle(theme.textTertiary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) { Hairline() }
                    }
                }
            }

            HStack(spacing: 12) {
                Button("Back") {
                    withAnimation(SightMotion.spring) { step = 0 }
                }
                .buttonStyle(SightButtonStyle(kind: .ghost))

                Button("Continue") {
                    withAnimation(SightMotion.spring) { step = 2 }
                }
                .buttonStyle(SightButtonStyle(kind: .primary))
                .disabled(model.rootURL == nil)
                .opacity(model.rootURL == nil ? 0.35 : 1)
            }
        }
    }

    private var modelStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            SectionHeader(title: "02 / MODEL", subtitle: "One-time setup.")

            Text("Text + vision. \(model.formattedModelSize). Runs entirely on this Mac. Your files never leave it.")
                .font(SightFont.body())
                .foregroundStyle(theme.textSecondary)
                .frame(maxWidth: 520, alignment: .leading)

            modelStatus

            HStack(spacing: 12) {
                Button("Back") {
                    withAnimation(SightMotion.spring) { step = 1 }
                }
                .buttonStyle(SightButtonStyle(kind: .ghost))

                if model.modelState.isReady {
                    Button("Enter Sight") {
                        finish()
                    }
                    .buttonStyle(SightButtonStyle(kind: .primary))
                } else if case .notInstalled = model.modelState {
                    Button("Download & Prepare") {
                        Task { await model.downloadModel() }
                    }
                    .buttonStyle(SightButtonStyle(kind: .primary))
                } else if case .failed = model.modelState {
                    Button("Retry") {
                        Task { await model.downloadModel() }
                    }
                    .buttonStyle(SightButtonStyle(kind: .primary))
                }
            }

            Text("First preparation can take a few minutes. Later launches are fast.")
                .font(SightFont.micro())
                .tracking(0.04)
                .foregroundStyle(theme.textFaint)
        }
    }

    @ViewBuilder
    private var modelStatus: some View {
        switch model.modelState {
        case .checking:
            statusLine("Checking local assets…", progress: nil)
        case .notInstalled:
            statusLine("Model not installed", progress: nil)
        case .downloading(let progress, let file):
            statusLine(file, progress: progress)
        case .loading(let message):
            statusLine(message, progress: nil)
        case .ready:
            statusLine("Ready", progress: 1)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 6) {
                Text("Could not prepare the model")
                    .font(SightFont.label())
                    .foregroundStyle(theme.textPrimary)
                Text(message)
                    .font(SightFont.mono())
                    .foregroundStyle(theme.textTertiary)
                    .lineLimit(3)
            }
        }
    }

    private func statusLine(_ title: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(SightFont.micro())
                    .tracking(0.06)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if let progress {
                    Text("\(Int(progress * 100))%")
                        .font(SightFont.micro())
                        .foregroundStyle(theme.textTertiary)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.line).frame(height: 2)
                    if let progress {
                        Capsule()
                            .fill(theme.paper)
                            .frame(width: max(2, proxy.size.width * progress), height: 2)
                    } else {
                        Capsule()
                            .fill(theme.paper.opacity(0.5))
                            .frame(width: proxy.size.width * 0.3, height: 2)
                    }
                }
            }
            .frame(height: 3)
        }
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack {
            Text("LOCAL ONLY")
                .font(SightFont.micro())
                .tracking(0.12)
                .foregroundStyle(theme.textFaint)
            Spacer()
            Text("v0.1.0")
                .font(SightFont.micro())
                .foregroundStyle(theme.textFaint)
        }
    }

    private func finish() {
        model.config.hasCompletedOnboarding = true
        model.saveConfig()
        model.startMonitoring()
    }
}
