import SwiftUI
import AppKit

extension Notification.Name {
    static let focusInput = Notification.Name("HalfBaked.focusInput")
    static let goHome = Notification.Name("HalfBaked.goHome")
}

extension NSFont {
    static func serif(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        if let d = base.fontDescriptor.withDesign(.serif), let f = NSFont(descriptor: d, size: size) { return f }
        return base
    }
}

/// NSTextView with: Return = submit, Shift/Option+Return = newline, Esc = escape,
/// a drawn placeholder, and IME-safe behaviour (Return while composing confirms the composition).
final class InkTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onEscape: (() -> Void)?
    var onResize: (() -> Void)?
    var onUp: (() -> Bool)?
    var onDown: (() -> Bool)?
    var onTab: (() -> Bool)?
    var onFocus: (() -> Void)?
    var placeholder = "" { didSet { needsDisplay = true } }

    override func insertNewline(_ sender: Any?) {
        let flags = NSApp.currentEvent?.modifierFlags ?? []
        if flags.contains(.shift) || flags.contains(.option) {
            insertNewlineIgnoringFieldEditor(sender)
        } else {
            onSubmit?()
        }
    }

    override func cancelOperation(_ sender: Any?) { onEscape?() }

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok, let onFocus { DispatchQueue.main.async { onFocus() } }
        return ok
    }

    override func insertTab(_ sender: Any?) {
        if onTab?() == true { return }
        super.insertTab(sender)
    }

    override func moveUp(_ sender: Any?) {
        if onUp?() == true { return }
        super.moveUp(sender)
    }

    override func moveDown(_ sender: Any?) {
        if onDown?() == true { return }
        super.moveDown(sender)
    }

    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = newSize.width != frame.width
        super.setFrameSize(newSize)
        if widthChanged { onResize?() }
    }

    override func didChangeText() {
        super.didChangeText()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty, !placeholder.isEmpty else { return }
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font ?? NSFont.systemFont(ofSize: 14),
            .foregroundColor: Theme.placeholderNS,
        ]
        let x = textContainerOrigin.x + (textContainer?.lineFragmentPadding ?? 0)
        (placeholder as NSString).draw(at: NSPoint(x: x, y: textContainerOrigin.y), withAttributes: attrs)
    }
}

struct InkEditor: View {
    @Binding var text: String
    var placeholder = ""
    var fontSize: CGFloat = 15
    var weight: NSFont.Weight = .regular
    var pixel = false
    var maxHeight: CGFloat? = nil
    var autofocus = false
    var focusID: String? = nil
    var onSubmit: () -> Void = {}
    var onEscape: () -> Void = {}
    var onBlur: () -> Void = {}
    var onUp: (() -> Bool)? = nil
    var onDown: (() -> Bool)? = nil
    var onTab: (() -> Bool)? = nil
    var onFocus: (() -> Void)? = nil

    @Environment(\.zoom) private var zoom
    @State private var height: CGFloat = 22

    var body: some View {
        InkRep(text: $text, height: $height, placeholder: placeholder, fontSize: fontSize * zoom, weight: weight, pixel: pixel,
               scrolls: maxHeight != nil, autofocus: autofocus, focusID: focusID,
               onSubmit: onSubmit, onEscape: onEscape, onBlur: onBlur, onUp: onUp, onDown: onDown, onTab: onTab,
               onFocus: onFocus)
            .frame(height: maxHeight.map { min(height, $0 * zoom) } ?? height)
    }
}

private struct InkRep: NSViewRepresentable {
    @Binding var text: String
    @Binding var height: CGFloat
    var placeholder: String
    var fontSize: CGFloat
    var weight: NSFont.Weight
    var pixel: Bool
    var scrolls: Bool
    var autofocus: Bool
    var focusID: String?
    var onSubmit: () -> Void
    var onEscape: () -> Void
    var onBlur: () -> Void
    var onUp: (() -> Bool)?
    var onDown: (() -> Bool)?
    var onTab: (() -> Bool)?
    var onFocus: (() -> Void)?

    var font: NSFont { pixel ? Theme.pixelNS(fontSize) : Theme.bookNS(fontSize) }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSView {
        let c = context.coordinator
        let tv = InkTextView(usingTextLayoutManager: false)
        c.tv = tv
        tv.delegate = c
        tv.drawsBackground = false
        tv.isRichText = false
        tv.importsGraphics = false
        tv.allowsUndo = true
        tv.insertionPointColor = Theme.accentNS
        tv.selectedTextAttributes = [.backgroundColor: Theme.accentNS.withAlphaComponent(0.22)]
        tv.textContainerInset = NSSize(width: 0, height: 2)
        tv.isContinuousSpellCheckingEnabled = true
        tv.isAutomaticSpellingCorrectionEnabled = false
        tv.isAutomaticQuoteSubstitutionEnabled = true
        tv.isAutomaticDashSubstitutionEnabled = true
        tv.isAutomaticTextReplacementEnabled = true
        c.applyFont(font)
        tv.placeholder = placeholder
        tv.onSubmit = { [weak c] in c?.parent.onSubmit() }
        tv.onEscape = { [weak c] in c?.parent.onEscape() }
        tv.onResize = { [weak c] in c?.recalc() }
        tv.onUp = { [weak c] in c?.parent.onUp?() ?? false }
        tv.onDown = { [weak c] in c?.parent.onDown?() ?? false }
        tv.onTab = { [weak c] in c?.parent.onTab?() ?? false }
        tv.onFocus = { [weak c] in c?.parent.onFocus?() }
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        c.setText(text)

        if let focusID {
            c.observer = NotificationCenter.default.addObserver(forName: .focusInput, object: nil, queue: .main) { [weak tv] note in
                guard let tv, (note.object as? String) == focusID else { return }
                tv.window?.makeFirstResponder(tv)
                tv.setSelectedRange(NSRange(location: (tv.string as NSString).length, length: 0))
            }
        }
        if autofocus {
            DispatchQueue.main.async { tv.window?.makeFirstResponder(tv) }
        }
        DispatchQueue.main.async { c.recalc() }

        guard scrolls else {
            tv.isVerticallyResizable = false
            tv.isHorizontallyResizable = false
            return tv
        }
        let sv = NSScrollView()
        sv.drawsBackground = false
        sv.borderType = .noBorder
        sv.hasVerticalScroller = true
        sv.autohidesScrollers = true
        tv.minSize = .zero
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        sv.documentView = tv
        return sv
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        let c = context.coordinator
        c.parent = self
        guard let tv = c.tv else { return }
        if tv.placeholder != placeholder { tv.placeholder = placeholder }
        let f = font
        if abs((tv.font?.pointSize ?? 0) - f.pointSize) > 0.01 && !tv.hasMarkedText() {
            c.applyFont(f)
            c.recalc()
        }
        if tv.string != text && !tv.hasMarkedText() {
            c.setText(text)
            c.recalc()
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: InkRep
        weak var tv: InkTextView?
        var observer: NSObjectProtocol?

        init(_ parent: InkRep) { self.parent = parent }
        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

        /// Set the font (used at creation and whenever the window zoom changes).
        func applyFont(_ font: NSFont) {
            guard let tv else { return }
            tv.font = font
            let ps = NSMutableParagraphStyle()
            ps.lineSpacing = font.pointSize * 0.22
            tv.defaultParagraphStyle = ps
            tv.typingAttributes = [.font: font, .foregroundColor: Theme.inkNS, .paragraphStyle: ps]
            if let storage = tv.textStorage, storage.length > 0 {
                storage.setAttributes(tv.typingAttributes, range: NSRange(location: 0, length: storage.length))
            }
            tv.needsDisplay = true
        }

        func setText(_ s: String) {
            guard let tv else { return }
            tv.string = s
            if let storage = tv.textStorage {
                storage.setAttributes(tv.typingAttributes, range: NSRange(location: 0, length: storage.length))
            }
            tv.needsDisplay = true
        }

        func recalc() {
            guard let tv, let lm = tv.layoutManager, let tc = tv.textContainer, tv.frame.width > 0 else { return }
            lm.ensureLayout(for: tc)
            let line = lm.defaultLineHeight(for: tv.font ?? .systemFont(ofSize: 14))
            let h = ceil(max(lm.usedRect(for: tc).height, line) + tv.textContainerInset.height * 2)
            if abs(h - parent.height) > 0.5 {
                DispatchQueue.main.async { self.parent.height = h }
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let tv else { return }
            parent.text = tv.string
            recalc()
        }

        func textDidEndEditing(_ notification: Notification) { parent.onBlur() }
    }
}
