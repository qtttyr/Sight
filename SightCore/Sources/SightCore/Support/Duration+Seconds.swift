import Foundation

extension Duration {
    /// The duration in seconds, as a plain number.
    ///
    /// `Duration` keeps its parts in seconds and attoseconds; this is the
    /// bridge to the `TimeInterval` the rest of the app counts in.
    public var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}
