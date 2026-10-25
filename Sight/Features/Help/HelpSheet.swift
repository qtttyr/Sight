import SwiftUI

/// How Sight actually works, in five short cards. Opened from the "?" pill in
/// the sidebar.
struct HelpSheet: View {
    @Environment(\.sightTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("FIELD GUIDE")
                        .font(SightFont.micro())
                        .tracking(0.18)
                        .foregroundStyle(theme.textTertiary)
                    Text("How Sight works.")
                        .font(SightFont.title())
                        .foregroundStyle(theme.textPrimary)
                }
                Spacer()
                SightIconButton(systemName: "xmark", help: "Close") {
                    dismiss()
                }
            }
            .padding(.bottom, 22)

            Hairline()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    step(
                        number: "01",
                        title: "The pipeline",
                        body:
                            "Sweep → read → embed → compare against your rules. A confident match becomes a proposal; everything else stays exactly where it is."
                    )
                    step(
                        number: "02",
                        title: "Review vs Auto",
                        body:
                            "Review is the default: every confident match waits for your approval, and the category folder is created the first time you approve a file. Auto moves confident files silently — switch between the two with the REVIEW / AUTO toggle on the Live screen or in Settings."
                    )
                    step(
                        number: "03",
                        title: "Memory",
                        body:
                            "A sweep remembers each decision. Unchanged files are skipped on the next sweep — only new and changed files go through the model again. Changing a rule re-runs everything touched by it once."
                    )
                    step(
                        number: "04",
                        title: "Coverage",
                        body:
                            "Files that belong to one of your rules get matched; the rest are left in place on purpose. Add rules for the content you actually have — the rule editor has tuned templates — or lower “Auto-sort confidence” in Settings."
                    )
                    step(
                        number: "05",
                        title: "Undo",
                        body:
                            "Every move is written to a journal before it happens, so the last sort can be put back in one click. Files you send back stay where they are."
                    )
                    step(
                        number: "06",
                        title: "Privacy",
                        body:
                            "The embedding model runs on this Mac, on the Neural Engine. Nothing you sort is uploaded, and the journal lets you undo any move."
                    )
                }
                .padding(.top, 20)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        }
        .padding(32)
        .frame(width: 560, height: 520)
        .background(theme.ink)
        .presentationBackground(theme.ink)
    }

    private func step(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(SightFont.micro())
                .foregroundStyle(theme.textFaint)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(SightFont.headline())
                    .foregroundStyle(theme.textPrimary)
                Text(body)
                    .font(SightFont.body())
                    .foregroundStyle(theme.textSecondary)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
    }
}
