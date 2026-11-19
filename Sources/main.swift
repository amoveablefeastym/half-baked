import AppKit
import SwiftUI
import Carbon
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let store = Store()
    let iconState = IconState()
    var icon: NSWindow!
    var window: NSWindow!
    private let defaults = Demo.defaults
    private var pinned: Bool { defaults.bool(forKey: "pinned") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Theme.registerFonts()
        NSApp.mainMenu = makeMenu()
        makeIcon()
        makePanel()
        if !Demo.on { registerHotKey() }
        NotificationCenter.default.addObserver(forName: .hidePanel, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.hidePanel() }
        }
        // A pinned panel comes back on launch; demo mode always opens it.
        if pinned || Demo.on { showPanel() }
    }

    // MARK: Floating icon

    private func makeIcon() {
        let size: CGFloat = 72
        let w = NSWindow(contentRect: NSRect(origin: savedIconOrigin(size), size: NSSize(width: size, height: size)),
                         styleMask: [.borderless], backing: .buffered, defer: false)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        w.isReleasedWhenClosed = false

        let container = IconView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        let host = NSHostingView(rootView: FloatingIcon(state: iconState).environmentObject(store))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        container.onClick = { [weak self] in self?.togglePanel() }
        container.onHover = { [weak self] h in self?.iconState.hover = h }
        container.onMoved = { [weak self] in
            guard let self else { return }
            defaults.set(icon.frame.origin.x, forKey: "iconX")
            defaults.set(icon.frame.origin.y, forKey: "iconY")
            if window.isVisible { placePanel() }
        }
        container.onMenu = { [weak self] e in self?.showIconMenu(e, in: container) }
        w.contentView = container
        if !Demo.on { w.orderFrontRegardless() }
        icon = w
    }

    private func savedIconOrigin(_ size: CGFloat) -> NSPoint {
        if defaults.object(forKey: "iconX") != nil {
            let p = NSPoint(x: defaults.double(forKey: "iconX"), y: defaults.double(forKey: "iconY"))
            let r = NSRect(origin: p, size: NSSize(width: size, height: size))
            if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(r) }) { return p }
        }
        let wa = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(x: wa.maxX - size - 24, y: wa.maxY - wa.height / 3 - size)
    }

    private func showIconMenu(_ event: NSEvent, in view: NSView) {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Half-Baked", action: #selector(openFromMenu), keyEquivalent: "").target = self
        let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    @objc private func openFromMenu() { showPanel() }

    @objc private func toggleLogin() {
        let svc = SMAppService.mainApp
        if svc.status == .enabled { try? svc.unregister() } else { try? svc.register() }
    }

    // MARK: Panel

    private func makePanel() {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
                         styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        for b in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            w.standardWindowButton(b)?.isHidden = true
        }
        w.backgroundColor = NSColor.dynamic(NSColor(hex: 0xF8EFDF), NSColor(hex: 0x241812))
        w.level = .floating
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Not movable by background: that would swallow drags of idea cards onto shelves.
        // The empty title-bar strip along the top still moves the window.
        w.isMovableByWindowBackground = false
        w.minSize = NSSize(width: 680, height: 460)
        w.isReleasedWhenClosed = false
        w.delegate = self
        let host = NSHostingView(rootView: RootView().environmentObject(store).defaultAppStorage(Demo.defaults))
        host.sizingOptions = []
        w.contentView = host
        window = w
    }

    /// Put the panel beside the icon, on whichever side has room.
    private func placePanel() {
        if Demo.on {
            let wa = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let s = NSSize(width: min(Demo.size.width, wa.width - 40), height: min(Demo.size.height, wa.height - 40))
            window.setFrame(NSRect(x: wa.midX - s.width / 2, y: wa.midY - s.height / 2, width: s.width, height: s.height), display: true)
            return
        }
        let b = icon.frame
        let wa = (icon.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let gap: CGFloat = 12
        let savedW = defaults.double(forKey: "panelW"), savedH = defaults.double(forKey: "panelH")
        let width = min(max(savedW > 0 ? savedW : 900, 680), wa.width - 16)
        let height = min(max(savedH > 0 ? savedH : 620, 460), wa.height - 16)
        let onRight = b.midX > wa.midX
        var x = onRight ? b.minX - width - gap : b.maxX + gap
        x = min(max(x, wa.minX + 8), wa.maxX - width - 8)
        var top = b.midY + 60
        top = min(max(top, wa.minY + 8 + height), wa.maxY - 8)
        window.setFrame(NSRect(x: x, y: top - height, width: width, height: height), display: true)
    }

    func showPanel() {
        placePanel()
        window.alphaValue = 0
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            window.animator().alphaValue = 1
        }
        iconState.open = true
        if !(window.firstResponder is NSTextView) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                NotificationCenter.default.post(name: .focusInput, object: "home")
            }
        }
    }

    func hidePanel() {
        guard window.isVisible else { return }
        window.orderOut(nil)
        iconState.open = false
        if NSApp.isActive { NSApp.deactivate() }
    }

    func togglePanel() {
        if window.isVisible && window.isKeyWindow { hidePanel() } else { showPanel() }
    }

    @objc func newIdea(_ sender: Any?) {
        NotificationCenter.default.post(name: .goHome, object: nil)
        showPanel()
    }

    // Opening the app again (Finder, Spotlight) shows the panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }

    // Click anywhere else and it tucks away, unless pinned.
    func windowDidResignKey(_ notification: Notification) {
        if !pinned { hidePanel() }
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        defaults.set(window.frame.width, forKey: "panelW")
        defaults.set(window.frame.height, forKey: "panelH")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        hidePanel()
        return false
    }

    @objc func closePanel(_ sender: Any?) { hidePanel() }

    // MARK: Global shortcut ⌃⌥B

    private func registerHotKey() {
        var ref: EventHotKeyRef?
        let id = EventHotKeyID(signature: OSType(0x4842_4B44), id: 1) // "HBKD"
        RegisterEventHotKey(UInt32(kVK_ANSI_B), UInt32(controlKey | optionKey), id,
                            GetApplicationEventTarget(), 0, &ref)
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { (NSApp.delegate as? AppDelegate)?.togglePanel() }
            }
            return noErr
        }, 1, &spec, nil, nil)
    }

    private func makeMenu() -> NSMenu {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let app = NSMenu()
        app.addItem(withTitle: "New Idea", action: #selector(newIdea(_:)), keyEquivalent: "n").target = self
        app.addItem(withTitle: "Close", action: #selector(closePanel(_:)), keyEquivalent: "w").target = self
        app.addItem(.separator())
        app.addItem(withTitle: "Quit Half-Baked", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = app
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        return main
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.run()
