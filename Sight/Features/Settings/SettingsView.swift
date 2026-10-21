import AppKit
import SightCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    @State private var showPurgeConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "SETTINGS", subtitle: "Quiet controls.")

                folderCard
                sortingCard
                appearanceCard
                modelCard
                aboutCard
            }
            .padding(.horizontal, 40)
            .padding(.top, 38)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog(
            "Remove the local model?",
            isPresented: $showPurgeConfirmation
        ) {
            Button("Remove Model", role: .destructive) {
                model.purgeModel()
            }
        } message: {
            Text("You can download it again at any time.")
        }
    }

    private var folderCard: some View {
        SightCard {
            VStack(alignment: .leading, spacing: 0) {
                cardTitle("WATCHED FOLDER")
                row(
                    "Root",
                    subtitle: model.rootDisplayPath
                ) {
                    Button("Change") { model.chooseFolder() }
                        .buttonStyle(SightButtonStyle(kind: .ghost))
                }
                Hairline()
                row(
                    "Scope",
                    subtitle: "Only files directly inside the root are touched. Subfolders are never entered."
                ) {
                    Text("ROOT ONLY")
                        .font(SightFont.micro())
                        .foregroundStyle(theme.textFaint)
                }
            }
        }
    }

    private var sortingCard: some View {
        SightCard {
            VStack(alignment: .leading, spacing: 0) {
                cardTitle("SORTING")
                row(
                    "Mode",
                    subtitle: model.config.mode == .auto
                        ? "Sight moves files immediately when confidence is high."
                        : "Sight proposes moves; you approve them."
                ) {
                    SightSegmented(
                        options: [
                            SightSegment(id: SortMode.review, label: "REVIEW"),
                            SightSegment(id: SortMode.auto, label: "AUTO")
                        ],
                        selection: modeBinding
                    )
                }
                Hairline()
                row(
                    "Threshold",
                    subtitle: "Minimum similarity before a category is considered."
                ) {
                    HStack(spacing: 12) {
                        SightSlider(
                            value: thresholdBinding,
                            range: 0.15...0.75,
                            step: 0.01
                        )
                        .frame(width: 180)
                        Text(String(format: "%.2f", model.config.threshold))
                            .font(SightFont.mono())
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                Hairline()
                row(
                    "Embedding size",
                    subtitle: "Smaller vectors are faster and use less memory. 256 is the default."
                ) {
                    SightSegmented(
                        options: EmbeddingDimension.allCases.map {
                            SightSegment(id: $0, label: $0.label)
                        },
                        selection: dimensionBinding
                    )
                }
            }
        }
    }

    private var appearanceCard: some View {
        SightCard {
            VStack(alignment: .leading, spacing: 0) {
                cardTitle("APPEARANCE")
                row(
                    "Theme",
                    subtitle: "Pure black and pure white. No color, no noise."
                ) {
                    SightSegmented(
                        options: [
                            SightSegment(id: ThemeMode.system, label: "SYSTEM"),
                            SightSegment(id: ThemeMode.dark, label: "DARK"),
                            SightSegment(id: ThemeMode.light, label: "LIGHT")
                        ],
                        selection: themeBinding
                    )
                }
            }
        }
    }

    private var modelCard: some View {
        SightCard {
            VStack(alignment: .leading, spacing: 0) {
                cardTitle("MODEL")

                row(
                    "Text + code",
                    subtitle: "EmbeddingGemma 2 · 768 dimensions · Apache-2.0"
                ) {
                    Text("ALWAYS ON")
                        .font(SightFont.micro())
                        .tracking(0.08)
                        .foregroundStyle(theme.textFaint)
                }
                Hairline()
                row(
                    "Images",
                    subtitle: "Understand screenshots, photos, and design files."
                ) {
                    SightSwitch(isOn: visionBinding)
                }
                Hairline()
                row(
                    "Audio",
                    subtitle: "Optional. Adds roughly 589 MB to the download."
                ) {
                    SightSwitch(isOn: audioBinding)
                }
                Hairline()
                row(
                    "Status",
                    subtitle: model.modelState.title
                ) {
                    Text(model.formattedModelSize)
                        .font(SightFont.mono())
                        .foregroundStyle(theme.textTertiary)
                }

                HStack(spacing: 12) {
                    if model.modelState.isReady {
                        Button("Reveal in Finder") {
                            model.revealModelFolder()
                        }
                        .buttonStyle(SightButtonStyle(kind: .ghost))

                        Button("Remove Model") {
                            showPurgeConfirmation = true
                        }
                        .buttonStyle(SightButtonStyle(kind: .ghost))
                    } else {
                        Button("Download & Prepare") {
                            Task { await model.downloadModel() }
                        }
                        .buttonStyle(SightButtonStyle(kind: .primary))
                    }

                    Spacer()

                    if let progress = downloadProgress {
                        Text("\(Int(progress * 100))%")
                            .font(SightFont.micro())
                            .foregroundStyle(theme.textTertiary)
                    }
                }
                .padding(.top, 18)
            }
        }
    }

    private var aboutCard: some View {
        SightCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle("ABOUT")
                HStack {
                    Text("Sight")
                        .font(SightFont.body())
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text("0.1.0")
                        .font(SightFont.mono())
                        .foregroundStyle(theme.textFaint)
                }
                HStack(spacing: 16) {
                    Link("Apache-2.0", destination: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!)
                    Link(
                        "EmbeddingGemma 2",
                        destination: URL(string: "https://huggingface.co/EverPaper/embeddinggemma-2-coreai")!
                    )
                    Spacer()
                    Text("NO TELEMETRY")
                        .font(SightFont.micro())
                        .tracking(0.1)
                        .foregroundStyle(theme.textFaint)
                }
                .font(SightFont.micro())
                .tint(theme.textSecondary)
            }
        }
    }

    private func cardTitle(_ title: String) -> some View {
        Text(title)
            .font(SightFont.micro())
            .tracking(0.16)
            .foregroundStyle(theme.textTertiary)
            .padding(.bottom, 8)
    }

    private func row<Content: View>(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SightFont.body())
                    .foregroundStyle(theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(SightFont.micro())
                        .tracking(0.02)
                        .foregroundStyle(theme.textFaint)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            content()
        }
        .padding(.vertical, 12)
    }

    private var themeBinding: Binding<ThemeMode> {
        Binding(
            get: { model.config.theme },
            set: { model.setTheme($0) }
        )
    }

    private var modeBinding: Binding<SortMode> {
        Binding(
            get: { model.config.mode },
            set: { mode in
                model.config.mode = mode
                model.config.autoSortEnabled = mode == .auto
                model.saveConfig()
            }
        )
    }

    private var thresholdBinding: Binding<Double> {
        Binding(
            get: { Double(model.config.threshold) },
            set: {
                model.config.threshold = Float($0)
                model.saveConfig()
            }
        )
    }

    private var dimensionBinding: Binding<EmbeddingDimension> {
        Binding(
            get: { model.config.dimension },
            set: { dimension in
                model.config.dimension = dimension
                model.saveConfig()
                Task { await model.refreshFingerprints() }
            }
        )
    }

    private var visionBinding: Binding<Bool> {
        Binding(
            get: { model.config.loadVision },
            set: { value in
                model.config.loadVision = value
                model.saveConfig()
                Task { await model.reloadModelForAssetChanges() }
            }
        )
    }

    private var audioBinding: Binding<Bool> {
        Binding(
            get: { model.config.loadAudio },
            set: { value in
                model.config.loadAudio = value
                model.saveConfig()
                Task { await model.reloadModelForAssetChanges() }
            }
        )
    }

    private var downloadProgress: Double? {
        if case .downloading(let progress, _) = model.modelState {
            return progress
        }
        return nil
    }
}
