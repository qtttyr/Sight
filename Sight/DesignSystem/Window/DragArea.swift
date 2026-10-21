import SwiftUI

/// An invisible strip that makes the whole top of the window draggable while
/// keeping the traffic lights interactive.
struct DragArea: View {
    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(WindowDragGesture())
    }
}
