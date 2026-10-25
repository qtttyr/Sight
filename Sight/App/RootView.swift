import SightCore
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .onAppear { SightMotion.reduceMotion = reduceMotion }
        .onChange(of: reduceMotion) { _, newValue in SightMotion.reduceMotion = newValue }
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
        .overlay(alignment: .bottom) {
            if let notice = model.notice {
                Text(notice)
                    .font(SightFont.body())
                    .foregroundStyle(theme.buttonLabel)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(theme.buttonFill))
                    .padding(.bottom, 28)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: notice) {
                        try? await Task.sleep(for: .seconds(4))
                        withAnimation(SightMotion.quick) { model.notice = nil }
                    }
            }
        }
        .animation(SightMotion.quick, value: model.notice)
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
