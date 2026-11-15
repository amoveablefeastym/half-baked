import AppKit
// Pixel-art golden loaf with steam on a flour-cream tile.
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
func hex(_ h: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((h >> 16) & 0xff) / 255, green: CGFloat((h >> 8) & 0xff) / 255, blue: CGFloat(h & 0xff) / 255, alpha: 1)
}
let inset: CGFloat = 100
let tile = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
hex(0x3B2416).setFill()
NSBezierPath(roundedRect: tile.offsetBy(dx: 0, dy: -14), xRadius: 120, yRadius: 120).fill()
hex(0xF8EFDF).setFill()
NSBezierPath(roundedRect: tile, xRadius: 120, yRadius: 120).fill()
// gingham, clipped to the tile
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: tile, xRadius: 120, yRadius: 120).addClip()
hex(0xD9585B).withAlphaComponent(0.08).setFill()
var x = tile.minX
while x < tile.maxX { NSRect(x: x, y: tile.minY + 40, width: 52, height: tile.height - 80).fill(); x += 104 }
NSGraphicsContext.restoreGraphicsState()

let rows = [
    "....w......w....",
    ".....w......w...",
    "....w......w....",
    "................",
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
let pal: [Character: NSColor] = ["o": hex(0x4A2C17), "M": hex(0xC98238), "H": hex(0xF2C46D), "S": hex(0x8E4E1F),
                                 "w": hex(0x3B2416).withAlphaComponent(0.35)]
let px: CGFloat = 44
let w = CGFloat(16) * px, h = CGFloat(rows.count) * px
let ox = (size - w) / 2, oy = (size - h) / 2 + h - px
for (r, row) in rows.enumerated() {
    for (c, ch) in row.enumerated() {
        guard let col = pal[ch] else { continue }
        col.setFill()
        NSRect(x: ox + CGFloat(c) * px, y: oy - CGFloat(r) * px, width: px, height: px).fill()
    }
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
