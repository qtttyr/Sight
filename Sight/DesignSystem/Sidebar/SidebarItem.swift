import SwiftUI

struct SidebarItem: View {
    let section: AppSection
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    @Environment(\.sightTheme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.icon)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .frame(width: 18, alignment: .leading)
                Text(section.title)
                    .font(SightFont.body())
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.active)
                        .matchedGeometryEffect(id: "sidebar-selection", in: namespace)
                } else if isHovering {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(theme.hover)
                }
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(theme.paper)
                        .frame(width: 2, height: 14)
                        .offset(x: -1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(SightMotion.quick) { isHovering = hovering }
        }
        .accessibilityLabel(section.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
