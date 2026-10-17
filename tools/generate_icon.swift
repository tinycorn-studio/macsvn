import AppKit

let size = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()

let inset: CGFloat = 90
let rect = NSRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2)
let path = NSBezierPath(roundedRect: rect, xRadius: 200, yRadius: 200)
let grad = NSGradient(colors: [
    NSColor(calibratedRed: 0.42, green: 0.62, blue: 1.0, alpha: 1),
    NSColor(calibratedRed: 0.22, green: 0.32, blue: 0.85, alpha: 1)
])!
grad.draw(in: path, angle: -90)

if let symbol = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: nil) {
    let cfg = NSImage.SymbolConfiguration(pointSize: 460, weight: .semibold)
    if let sym = symbol.withSymbolConfiguration(cfg) {
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        let r = NSRect(origin: .zero, size: sym.size)
        sym.draw(in: r)
        NSColor.white.set()
        r.fill(using: .sourceAtop)
        tinted.unlockFocus()
        let pos = NSRect(
            x: (CGFloat(size) - sym.size.width) / 2,
            y: (CGFloat(size) - sym.size.height) / 2,
            width: sym.size.width,
            height: sym.size.height
        )
        tinted.draw(in: pos)
    }
}

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("ERR: render failed")
    exit(1)
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
try png.write(to: URL(fileURLWithPath: out))
print("OK: \(out)")
