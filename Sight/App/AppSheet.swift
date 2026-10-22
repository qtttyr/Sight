import Foundation

/// The app's modal layer. Sight presents exactly one sheet at a time, and the
/// shell owns that presentation so no view competes for the window's sheet
/// context.
enum AppSheet: String, Identifiable, Hashable {
    case review
    case help
    case ruleEditor

    var id: String { rawValue }
}
