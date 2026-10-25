import SwiftUI

enum SightFont {
    static func display() -> Font {
        .system(size: 48, weight: .semibold).monospacedDigit()
    }

    static func title() -> Font {
        .system(size: 28, weight: .semibold)
    }

    static func headline() -> Font {
        .system(size: 17, weight: .semibold)
    }

    static func body() -> Font {
        .system(size: 13, weight: .regular)
    }

    static func label() -> Font {
        .system(size: 11, weight: .medium)
    }

    static func number() -> Font {
        .system(size: 32, weight: .medium).monospacedDigit()
    }

    static func micro() -> Font {
        .system(size: 10, weight: .semibold, design: .monospaced)
    }

    static func mono() -> Font {
        .system(size: 12, weight: .regular, design: .monospaced)
    }
}

enum SightSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let huge: CGFloat = 48
    static let giant: CGFloat = 64
}

enum SightRadius {
    static let control: CGFloat = 8
    static let row: CGFloat = 12
    static let card: CGFloat = 16
    static let pill: CGFloat = 22
}
