import SightCore
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme

    var body: some View {
        Group {
            if model.isBootstrapping {
                SplashView()
            } else if !model.config.hasCompletedOnboarding {
                OnboardingView()
            } else {
                AppShellView()
            }
        }
        .frame(minWidth: 980, minHeight: 640)
        .background(theme.ink)
        .preferredColorScheme(colorScheme)
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.clearError() } }
            )
        ) {
            Button("OK") { model.clearError() }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task {
            await model.bootstrap()
        }
    }

    private var colorScheme: ColorScheme? {
        switch model.config.theme {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

struct SplashView: View {
    @Environment(\.sightTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    var body: some View {
        VStack(spacing: 18) {
            Circle()
                .fill(theme.paper)
                .frame(width: 10, height: 10)
                .opacity(breathing ? 0.3 : 1)
                .animation(reduceMotion ? nil : SightMotion.breathe, value: breathing)
            Text("SIGHT")
                .font(SightFont.micro())
                .tracking(0.32)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.ink)
        .onAppear { breathing = true }
    }
}
