import Foundation

enum AppSection: String, CaseIterable, Identifiable {
    case live
    case rules
    case insights
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .live: "Live"
        case .rules: "Rules"
        case .insights: "Insights"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .live: "waveform.path.ecg"
        case .rules: "square.stack.3d.up"
        case .insights: "chart.bar.xaxis"
        case .settings: "slider.horizontal.3"
        }
    }
}
