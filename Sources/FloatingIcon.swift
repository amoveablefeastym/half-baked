import SwiftUI
import AppKit

extension Notification.Name {
    static let hidePanel = Notification.Name("HalfBaked.hidePanel")
}

final class IconState: ObservableObject {
    @Published var open = false
    @Published var hover = false
}

/// The steaming pixel loaf that floats on the desktop, with a count of rising ideas.
struct FloatingIcon: View {
    @EnvironmentObject var store: Store
    @ObservedObject var state: IconState
    @State private var bob = false

    var body: some View {
        Loaf(stage: 3, px: 3, steam: true)
            .offset(y: bob ? -3 : 2)
            .scaleEffect(state.hover || state.open ? 1.1 : 1)
            .shadow(color: Color(hex: 0xF28C28).opacity(state.open ? 0.7 : 0.3), radius: state.open ? 10 : 5)
            .frame(width: 72, height: 72)
            .overlay(alignment: .topTrailing) {
                let n = store.open.count
                if n > 0 {
                    Text("\(n)")
                        .font(.pixel(12))
                        .foregroundStyle(Sprites.outline)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(hex: 0xE9B44C))
                        .overlay(Rectangle().strokeBorder(Sprites.outline, lineWidth: 1.5))
                        .padding(.top, 10)
                        .padding(.trailing, 4)
                        .contentTransition(.numericText())
                }
            }
            .background(Circle().fill(Color.black.opacity(0.001))) // whole circle is clickable
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: state.hover)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.open)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) { bob = true }
            }
    }
}

/// Handles clicking, dragging and right-clicking the floating icon.
final class IconView: NSView {
    var onClick: (() -> Void)?
    var onMenu: ((NSEvent) -> Void)?
    var onMoved: (() -> Void)?
    var onHover: ((Bool) -> Void)?

    private var startMouse = NSPoint.zero
    private var startOrigin = NSPoint.zero
    private var moved = false

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? self : nil
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }

    override func mouseDown(with event: NSEvent) {
        startMouse = NSEvent.mouseLocation
        startOrigin = window?.frame.origin ?? .zero
        moved = false
    }

    override func mouseDragged(with event: NSEvent) {
        let p = NSEvent.mouseLocation
        let dx = p.x - startMouse.x, dy = p.y - startMouse.y
        if abs(dx) + abs(dy) > 4 { moved = true }
        guard moved else { return }
        window?.setFrameOrigin(NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy))
    }

    override func mouseUp(with event: NSEvent) {
        if moved { onMoved?() } else { onClick?() }
    }

    override func rightMouseDown(with event: NSEvent) { onMenu?(event) }
}
