import SightCore
import SwiftUI

extension Notification.Name {
    static let sightShowPalette = Notification.Name("app.sight.showPalette")
}

struct AppShellView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    @State private var showPalette = false

    var body: some View {
        @Bindable var model = model

        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                SightSidebar(
                    section: $model.section,
                    themeMode: model.config.theme,
                    modelState: model.modelState,
                    rootDisplayPath: model.rootDisplayPath,
                    onTheme: { model.setTheme($0) }
                )

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.ink)
                    .background(alignment: .top) {
                        DragArea()
                            .frame(height: 48)
                            .padding(.leading, 80)
                    }
            }
            .ignoresSafeArea()

            WindowAccessor(isDark: theme.isDark)
                .frame(width: 0, height: 0)

            if showPalette {
                CommandPaletteView(isPresented: $showPalette)
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .background(theme.ink)
        .onReceive(NotificationCenter.default.publisher(for: .sightShowPalette)) { _ in
            withAnimation(SightMotion.quick) { showPalette = true }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.section {
        case .live:
            LiveSorterView()
        case .rules:
            RulesView()
        case .insights:
            InsightsView()
        case .settings:
            SettingsView()
        }
    }
}
