import SwiftUI

enum SightMotion {
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let quick = Animation.easeOut(duration: 0.12)
    static let selection = Animation.spring(response: 0.28, dampingFraction: 0.9)
    static let breathe = Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true)
}
