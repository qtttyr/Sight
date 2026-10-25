import SwiftUI

/// Every animation in Sight lives here, so "Reduce Motion" can be honoured
/// in one place instead of in twenty views.
@MainActor
enum SightMotion {
    /// Mirrors the system setting. The root view keeps it up to date.
    static var reduceMotion = false

    /// An instant change, for when motion is not welcome.
    private static var instant: Animation { .linear(duration: 0.01) }

    static var spring: Animation {
        reduceMotion ? instant : .spring(response: 0.32, dampingFraction: 0.86)
    }

    static var selection: Animation {
        reduceMotion ? instant : .spring(response: 0.28, dampingFraction: 0.9)
    }

    static var quick: Animation {
        reduceMotion ? instant : .easeOut(duration: 0.12)
    }

    static var breathe: Animation {
        reduceMotion ? instant : .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
    }
}
