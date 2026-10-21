import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.sightTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Circle().fill(theme.paper).frame(width: 6, height: 6)
                Text("SIGHT")
                    .font(SightFont.micro())
                    .tracking(0.24)
                Spacer()
                Text(model.modelState.title)
                    .font(SightFont.micro())
                    .foregroundStyle(theme.textTertiary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(model.events.count)")
                    .font(.system(size: 28, weight: .medium).monospacedDigit())
                Text("EVENTS")
                    .font(SightFont.micro())
                    .foregroundStyle(theme.textTertiary)
            }

            Text(model.rootDisplayPath)
                .font(SightFont.micro())
                .foregroundStyle(theme.textFaint)
                .lineLimit(1)
                .truncationMode(.middle)

            Hairline()

            VStack(spacing: 2) {
                menuButton("Sweep Now", icon: "arrow.clockwise") {
                    Task { await model.runSweep() }
                }
                menuButton("Open Sight", icon: "macwindow") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first(where: { $0.canBecomeKey })?.makeKeyAndOrderFront(nil)
                }
                menuButton("Quit", icon: "power") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(18)
        .frame(width: 280)
        .background(theme.ink)
    }

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 16)
                Text(title)
                    .font(SightFont.body())
                Spacer()
            }
            .foregroundStyle(theme.textSecondary)
            .padding(.horizontal, 8)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
