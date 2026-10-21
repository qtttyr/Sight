import SwiftUI
import UniformTypeIdentifiers

struct DropZone: View {
    var title: String = "Drop a folder"
    var subtitle: String = "or click to choose one"
    var height: CGFloat = 150
    var onTap: (() -> Void)?
    let onURLs: ([URL]) -> Void

    @Environment(\.sightTheme) private var theme
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(isTargeted ? theme.paper : theme.textTertiary)
            Text(title)
                .font(SightFont.body())
                .foregroundStyle(isTargeted ? theme.paper : theme.textSecondary)
            Text(subtitle)
                .font(SightFont.micro())
                .tracking(0.08)
                .foregroundStyle(theme.textFaint)
        }
        .frame(maxWidth: .infinity, minHeight: height)
        .background {
            RoundedRectangle(cornerRadius: SightRadius.card, style: .continuous)
                .fill(isTargeted ? theme.hover : theme.surface.opacity(0.4))
        }
        .overlay {
            RoundedRectangle(cornerRadius: SightRadius.card, style: .continuous)
                .strokeBorder(
                    isTargeted ? theme.paper : theme.lineStrong,
                    style: StrokeStyle(lineWidth: 1, dash: [5, 5])
                )
        }
        .scaleEffect(isTargeted ? 1.008 : 1)
        .animation(SightMotion.spring, value: isTargeted)
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let url = Self.url(from: item) else { return }
                    Task { @MainActor in onURLs([url]) }
                }
            }
            return true
        }
    }

    private nonisolated static func url(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL { return url }
        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }
        if let string = item as? String {
            return URL(string: string)
        }
        return nil
    }
}
