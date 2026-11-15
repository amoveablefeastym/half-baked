import SwiftUI
import AppKit
import CoreText

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }
    static func dynamic(_ light: NSColor, _ dark: NSColor) -> NSColor {
        NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) { self.init(nsColor: NSColor(hex: hex, alpha: alpha)) }
}

/// Bakery palette: flour, crust, honey and jam. Dark mode is a warm oven at night.
enum Theme {
    static let pixelFamily = "Pixelify Sans"

    static func registerFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        for u in urls { CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil) }
    }

    static func pixelNS(_ size: CGFloat) -> NSFont {
        NSFont(descriptor: NSFontDescriptor(fontAttributes: [.family: pixelFamily]), size: size)
            ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }
    /// Body text uses the same pixel font, a touch larger for readability.
    static func bookNS(_ size: CGFloat) -> NSFont { pixelNS(size + 1) }

    static let inkNS = NSColor.dynamic(NSColor(hex: 0x3B2416), NSColor(hex: 0xF5E6CC))
    static let placeholderNS = NSColor.dynamic(NSColor(hex: 0x3B2416, alpha: 0.32), NSColor(hex: 0xF5E6CC, alpha: 0.3))
    static let accentNS = NSColor.dynamic(NSColor(hex: 0xC2702A), NSColor(hex: 0xF0A24A))

    static let ink = Color(nsColor: inkNS)
    static let accent = Color(nsColor: accentNS)
    static let honey = Color(nsColor: .dynamic(NSColor(hex: 0xE9B44C), NSColor(hex: 0xE9B44C)))
    static let flour = Color(nsColor: .dynamic(NSColor(hex: 0xF8EFDF), NSColor(hex: 0x241812)))
    static let shelf = Color(nsColor: .dynamic(NSColor(hex: 0xEEDDC0), NSColor(hex: 0x1B120D)))
    static let card = Color(nsColor: .dynamic(NSColor(hex: 0xFFF9EE), NSColor(hex: 0x30211A)))
    static let cardSoft = Color(nsColor: .dynamic(NSColor(hex: 0xFFF9EE, alpha: 0.55), NSColor(hex: 0x30211A, alpha: 0.6)))
    static let border = Color(nsColor: .dynamic(NSColor(hex: 0x3B2416, alpha: 0.85), NSColor(hex: 0xF5E6CC, alpha: 0.28)))
    static let shadow = Color(nsColor: .dynamic(NSColor(hex: 0x3B2416, alpha: 0.22), NSColor(white: 0, alpha: 0.55)))
    static let hairline = border.opacity(0.35)

    /// One "flavour" per idea: honey, strawberry jam, blueberry, matcha, cinnamon, apricot.
    static let palette: [Color] = [0xE9B44C, 0xD9585B, 0x6E7FC2, 0x8DB36B, 0xB8703A, 0xF29E6B].map { Color(hex: $0) }
}

// MARK: - Zoom (everything scales with the window)

private struct ZoomKey: EnvironmentKey { static let defaultValue: CGFloat = 1 }
extension EnvironmentValues {
    var zoom: CGFloat {
        get { self[ZoomKey.self] }
        set { self[ZoomKey.self] = newValue }
    }
}

private struct ZoomedFont: ViewModifier {
    @Environment(\.zoom) private var zoom
    let size: CGFloat
    func body(content: Content) -> some View { content.font(.pixel(size * zoom)) }
}

extension View {
    func pixelFont(_ size: CGFloat) -> some View { modifier(ZoomedFont(size: size)) }
    func bookFont(_ size: CGFloat) -> some View { modifier(ZoomedFont(size: size + 1)) }
}

extension Font {
    static func pixel(_ size: CGFloat) -> Font { .custom(Theme.pixelFamily, size: size) }
    static func book(_ size: CGFloat) -> Font { .pixel(size + 1) }
}

extension Item {
    var color: Color { Theme.palette[Int(id.uuid.0) % Theme.palette.count] }

    /// 0 dough · 1 rising · 2 shaped loaf · 3 baked
    var stage: Int {
        if done { return 3 }
        let s = steps
        guard !s.isEmpty else { return 0 }
        let f = Double(s.filter(\.done).count) / Double(s.count)
        return f == 0 ? 0 : (f < 0.5 ? 1 : 2)
    }
}

extension View {
    func pixelLabel() -> some View {
        pixelFont(12)
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(Theme.ink.opacity(0.55))
    }

    /// Chunky pixel card: crisp border and a hard offset shadow (strong), or a soft flat tile.
    func glass(_ radius: CGFloat = 4, strong: Bool = false) -> some View {
        let r = min(radius, 5)
        return background {
            ZStack {
                if strong {
                    RoundedRectangle(cornerRadius: r).fill(Theme.shadow).offset(x: 3, y: 3)
                }
                RoundedRectangle(cornerRadius: r).fill(strong ? Theme.card : Theme.cardSoft)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: r)
            .strokeBorder(strong ? Theme.border : Theme.hairline, lineWidth: strong ? 2 : 1.5))
    }
}

// MARK: - Pixel art

struct PixelSprite: View {
    let rows: [String]
    let palette: [Character: Color]
    var px: CGFloat = 3

    var body: some View {
        let w = rows.map(\.count).max() ?? 0
        Canvas { ctx, _ in
            for (y, row) in rows.enumerated() {
                for (x, ch) in row.enumerated() {
                    guard let c = palette[ch] else { continue }
                    ctx.fill(Path(CGRect(x: CGFloat(x) * px, y: CGFloat(y) * px,
                                         width: px + 0.02, height: px + 0.02)), with: .color(c))
                }
            }
        }
        .frame(width: CGFloat(w) * px, height: CGFloat(rows.count) * px)
    }
}

enum Sprites {
    static let outline = Color(hex: 0x4A2C17)

    static let dough = [
        "....oooooo....",
        "..oohhdddDoo..",
        ".ohhddddddDDo.",
        "ohhdddddddddDo",
        "odddddddddddDo",
        "oDdddddddddDDo",
        ".oDDDDDDDDDDo.",
        "..oooooooooo..",
    ]

    static let rising = [
        ".....oooooo.....",
        "...oohhdddDoo...",
        "..ohhddddddDDo..",
        "..ohddddddddDo..",
        "oooooooooooooooo",
        "oLbbbbbbbbbbbbno",
        ".oLbbbbbbbbbbno.",
        "..obbbbbbbbbno..",
        "...onnnnnnnno...",
        "....oooooooo....",
    ]

    static let loaf = [
        ".....oooooo.....",
        "...ooMMMMMMoo...",
        "..oMMHMMMHMMMo..",
        ".oMMHMMMHMMMHMo.",
        "oMMHMMMHMMMHMMSo",
        "oMMMMMMMMMMMMMSo",
        "oSMMMMMMMMMMMSSo",
        ".oSSSSSSSSSSSSo.",
        "..oooooooooooo..",
    ]

    static let doughPalette: [Character: Color] = [
        "o": outline, "h": Color(hex: 0xFFF8EA), "d": Color(hex: 0xF4E4C4), "D": Color(hex: 0xDCC398),
        "b": Color(hex: 0x8FB3CF), "L": Color(hex: 0xBBD5E8), "n": Color(hex: 0x6A8FAE),
    ]
    static let shapedPalette: [Character: Color] = [
        "o": outline, "M": Color(hex: 0xEBC98A), "H": Color(hex: 0xF8E6BC), "S": Color(hex: 0xC99A55),
    ]
    static let bakedPalette: [Character: Color] = [
        "o": outline, "M": Color(hex: 0xC98238), "H": Color(hex: 0xF2C46D), "S": Color(hex: 0x8E4E1F),
    ]

    static let steam: [[String]] = [
        ["....w......w....", ".....w......w...", "....w......w....", "................"],
        [".....w......w...", "....w......w....", ".....w......w...", "................"],
    ]

    static let oven = [
        "oooooooooooooooooooo",
        "ommmmmmmmmmmmmmmmmmo",
        "omkmkmkmmmmmmmmllmmo",
        "ommmmmmmmmmmmmmmmmmo",
        "oooooooooooooooooooo",
        "ommmmmmmmmmmmmmmmmmo",
        "omMMMMMMMMMMMMMMMMmo",
        "omMggggggggggggggMmo",
        "omMggggggggggggggMmo",
        "omMggggggggggggggMmo",
        "omMggggggggggggggMmo",
        "omMggggggggggggggMmo",
        "omMMMMMMMMMMMMMMMMmo",
        "ommmmmllllllllmmmmmo",
        "ommmmmmmmmmmmmmmmmmo",
        "oooooooooooooooooooo",
        ".oo..............oo.",
    ]
    static let ovenPalette: [Character: Color] = [
        "o": Color(hex: 0x2E2026), "m": Color(hex: 0xB9A9A0), "M": Color(hex: 0x6E5F5A),
        "k": Color(hex: 0x3B2416), "l": Color(hex: 0xE9DCD2), "g": Color(hex: 0x4A2216),
        "f": Color(hex: 0xF28C28), "y": Color(hex: 0xFFD25A), "r": Color(hex: 0xE0533A),
    ]
    static let flames: [[String]] = [
        ["kfkkykkfkkykkf", "fyrfyfrfyfrfyf"],
        ["kkykkfkkykkfkk", "yfrfyrfyfyrfyr"],
        ["ykkfkkykkfkkyk", "rfyfrfyrfrfyrf"],
    ]
}

/// The loaf that shows how baked an idea is.
struct Loaf: View {
    let stage: Int
    var px: CGFloat = 2
    var steam = false
    @Environment(\.zoom) private var zoom

    var body: some View {
        let px = px * zoom
        return VStack(spacing: 0) {
            if stage == 3 && steam {
                TimelineView(.periodic(from: .now, by: 0.4)) { ctx in
                    let f = Int(ctx.date.timeIntervalSinceReferenceDate / 0.4) % 2
                    PixelSprite(rows: Sprites.steam[f], palette: ["w": Theme.ink.opacity(0.35)], px: px)
                }
            }
            sprite(px)
        }
        .frame(width: 16 * px, alignment: .bottom)
    }

    @ViewBuilder private func sprite(_ px: CGFloat) -> some View {
        switch stage {
        case 0: PixelSprite(rows: Sprites.dough, palette: Sprites.doughPalette, px: px)
        case 1: PixelSprite(rows: Sprites.rising, palette: Sprites.doughPalette, px: px)
        case 2: PixelSprite(rows: Sprites.loaf, palette: Sprites.shapedPalette, px: px)
        default: PixelSprite(rows: Sprites.loaf, palette: Sprites.bakedPalette, px: px)
        }
    }
}

/// Little oven with flickering flames, for the home screen.
struct Oven: View {
    var px: CGFloat = 6
    @Environment(\.zoom) private var zoom
    var body: some View {
        let px = px * zoom
        return TimelineView(.periodic(from: .now, by: 0.18)) { ctx in
            let f = Sprites.flames[Int(ctx.date.timeIntervalSinceReferenceDate / 0.18) % 3]
            var rows = Sprites.oven
            rows[10] = "omM" + f[0] + "Mmo"
            rows[11] = "omM" + f[1] + "Mmo"
            return PixelSprite(rows: rows, palette: Sprites.ovenPalette, px: px)
                .shadow(color: Color(hex: 0xF28C28).opacity(0.25), radius: 18, y: 6)
        }
    }
}

/// Segmented pixel progress bar.
struct PixelProgress: View {
    let value: Double
    var segments = 16
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { i in
                Rectangle()
                    .fill(Double(i) < value * Double(segments) - 0.001 ? Theme.honey : Theme.ink.opacity(0.1))
                    .frame(height: 6)
            }
        }
        .padding(2)
        .overlay(Rectangle().strokeBorder(Theme.border, lineWidth: 1.5))
    }
}

/// Faint gingham tablecloth for the shelf.
struct Gingham: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 14
            let c = Color(hex: 0xD9585B).opacity(0.05)
            var x: CGFloat = 0
            while x < size.width { ctx.fill(Path(CGRect(x: x, y: 0, width: s, height: size.height)), with: .color(c)); x += s * 2 }
            var y: CGFloat = 0
            while y < size.height { ctx.fill(Path(CGRect(x: 0, y: y, width: size.width, height: s)), with: .color(c)); y += s * 2 }
        }
        .allowsHitTesting(false)
    }
}
