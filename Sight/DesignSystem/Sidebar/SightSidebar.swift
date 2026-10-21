import SightCore
import SwiftUI

struct SightSidebar: View {
    @Binding var section: AppSection
    let themeMode: ThemeMode
    let modelState: ModelState
    let rootDisplayPath: String
    let onTheme: (ThemeMode) -> Void

    @Environment(\.sightTheme) private var theme
    @Namespace private var selectionNamespace
    @State private var isPaletteHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.top, 64)
                .padding(.horizontal, 24)

            Spacer(minLength: 40)

            VStack(spacing: 4) {
                ForEach(AppSection.allCases) { item in
                    SidebarItem(
                        section: item,
                        isSelected: section == item,
                        namespace: selectionNamespace
                    ) {
                        withAnimation(SightMotion.selection) {
                            section = item
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            footer
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(width: 240)
        .background(theme.sidebar)
        .overlay(alignment: .trailing) {
            Hairline(axis: .vertical)
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(theme.paper)
                .frame(width: 8, height: 8)
            Text("SIGHT")
                .font(SightFont.micro())
                .tracking(0.28)
                .foregroundStyle(theme.textPrimary)
            Spacer()
            Text("01")
                .font(SightFont.micro())
                .foregroundStyle(theme.textFaint)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                LiveDot(isActive: modelState.isReady)
                Text(modelState.title)
                    .font(SightFont.micro())
                    .tracking(0.08)
                    .foregroundStyle(modelState.isReady ? theme.textSecondary : theme.textTertiary)
                Spacer()
            }

            Text(rootDisplayPath)
                .font(SightFont.micro())
                .foregroundStyle(theme.textFaint)
                .lineLimit(1)
                .truncationMode(.middle)

            HStack(spacing: 12) {
                themeSwitch
                    .frame(width: 132)
                paletteButton
                Spacer()
            }
        }
    }

    private var paletteButton: some View {
        Button {
            NotificationCenter.default.post(name: .sightShowPalette, object: nil)
        } label: {
            Text("⌘K")
                .font(SightFont.micro())
                .foregroundStyle(isPaletteHovering ? theme.textPrimary : theme.textTertiary)
                .padding(.horizontal, 10)
                .frame(height: 20)
                .background {
                    if isPaletteHovering {
                        Capsule().fill(theme.hover)
                    }
                }
                .overlay {
                    Capsule().stroke(theme.line, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Command Palette")
        .onHover { hovering in
            withAnimation(SightMotion.quick) {
                isPaletteHovering = hovering
            }
        }
    }

    private var themeSwitch: some View {
        HStack(spacing: 2) {
            themeButton("DARK", mode: .dark)
            themeButton("LIGHT", mode: .light)
            Spacer()
        }
        .padding(2)
        .background(theme.hover)
        .clipShape(Capsule())
        .frame(width: 132)
    }

    private func themeButton(_ title: String, mode: ThemeMode) -> some View {
        Button {
            withAnimation(SightMotion.quick) { onTheme(mode) }
        } label: {
            Text(title)
                .font(SightFont.micro())
                .tracking(0.08)
                .foregroundStyle(themeMode == mode ? theme.buttonLabel : theme.textTertiary)
                .padding(.horizontal, 10)
                .frame(height: 20)
                .background {
                    if themeMode == mode {
                        Capsule().fill(theme.buttonFill)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
