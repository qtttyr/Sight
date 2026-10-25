import AppKit
import SightCore
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    @State private var showPurgeConfirmation = false
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeader(title: "SETTINGS", subtitle: "Quiet controls.")

                folderCard
                sortingCard
                appearanceCard
                modelCard
                resetCard
                aboutCard
            }
            .padding(.horizontal, 40)
            .padding(.top, 38)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .confirmationDialog(
            "Start over?",
            isPresented: $showResetConfirmation
        ) {
            Button("Forget Everything", role: .destructive) {
                Task { await model.startOver() }
            }
        } message: {
            Text("Your rules, history and watched folder are removed. Sight returns to the setup flow.")
        }
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
                            SightSegment(id: SortMode.auto, label: "AUTO"),
                        ],
                        selection: modeBinding,
                        label: "Sorting mode"
                    )
                }
                Hairline()
                row(
                    "Auto-sort confidence",
                    subtitle:
                        "How sure Sight must be before it moves a file on its own. Everything below still gets a proposal in Review, so nothing is left behind."
                ) {
                    HStack(spacing: 12) {
                        SightSlider(
                            value: confidenceBinding,
                            range: Double(
                                SightConfig.confidenceRange.lowerBound)...Double(SightConfig.confidenceRange.upperBound),
                            step: 0.01,
                            label: "Auto-sort confidence",
                            valueLabel: "percent"
                        )
                        .frame(width: 180)
                        Text(String(format: "%.0f%%", model.config.confidence * 100))
                            .font(SightFont.mono())
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 36, alignment: .trailing)
                    }
                }
                Hairline()
                row(
                    "Rename unclear files",
                    subtitle:
                        "Files named like IMG_0059 or scan_0041 get a clear name taken from the file itself. Names that already say something are never changed, and undo restores the original."
                ) {
                    SightSegmented(
                        options: [SightSegment(id: true, label: "ON"), SightSegment(id: false, label: "OFF")],
                        selection: Binding(
                            get: { model.config.renameFiles },
                            set: {
                                model.config.renameFiles = $0; model.saveConfig()
                            }
                        ),
                        label: "Rename unclear files"
                    )
                }
                Hairline()
                row(
                    "Suggest new folders",
                    subtitle:
                        "When at least five files fit no category but belong together, Sight offers one new folder for them. Never one folder per file."
                ) {
                    SightSegmented(
                        options: [SightSegment(id: true, label: "ON"), SightSegment(id: false, label: "OFF")],
                        selection: Binding(
                            get: { model.config.suggestFolders },
                            set: {
                                model.config.suggestFolders = $0; model.saveConfig()
                            }
                        ),
                        label: "Suggest new folders"
                    )
                }
                Hairline()
                row(
                    "Embedding size",
                    subtitle:
                        "Full size (768) is the most accurate and just as fast. Smaller vectors only help on very constrained Macs."
                ) {
                    SightSegmented(
                        options: EmbeddingDimension.allCases.map {
                            SightSegment(id: $0, label: $0.label)
                        },
                        selection: dimensionBinding,
                        label: "Embedding size"
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
                            SightSegment(id: ThemeMode.light, label: "LIGHT"),
                        ],
                        selection: themeBinding,
                        label: "Theme"
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
                    SightSwitch(
                        isOn: visionBinding,
                        label: "Images",
                        help: "Understand screenshots, photos and design files."
                    )
                }
                Hairline()
                row(
                    "Audio",
                    subtitle: "Optional. Adds roughly 589 MB to the download."
                ) {
                    SightSwitch(
                        isOn: audioBinding,
                        label: "Audio",
                        help: "Adds roughly 589 MB to the download."
                    )
                }
                Hairline()
                row(
                    "Status",
                    subtitle: modelStatusDetail
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
                        .disabled(model.modelState.isBusy)
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

    /// Wipes the setup: rules, history, remembered decisions and the watched
    /// folder. The app returns to onboarding and starts over. The downloaded
    /// model stays — it is a download, not a memory.
    private var resetCard: some View {
        SightCard {
            VStack(alignment: .leading, spacing: 0) {
                cardTitle("START OVER")
                row(
                    "Forget everything",
                    subtitle:
                        "Removes your rules, history and watched folder, then walks you through the setup again. The downloaded model is kept."
                ) {
                    Button("Start Over") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(SightButtonStyle(kind: .ghost))
                }
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

    private var confidenceBinding: Binding<Double> {
        Binding(
            get: { Double(model.config.confidence) },
            set: {
                model.config.confidence = Float($0)
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

    /// The real reason behind the model state. A bare "MODEL ERROR" leaves
    /// the user with nothing to act on.
    private var modelStatusDetail: String {
        switch model.modelState {
        case .failed(let message):
            return message
        case .ready:
            return "Ready · \(model.formattedModelSize) on disk"
        case .downloading:
            return "Downloading…"
        case .loading(let message):
            return message
        case .checking:
            return "Checking the local files…"
        case .notInstalled:
            return "Not downloaded yet."
        }
    }
}
