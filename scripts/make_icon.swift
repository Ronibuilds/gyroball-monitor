// Renders the Gyroball app icon: SF Symbol "gyroscope" on a gradient squircle.
// Run: swift scripts/make_icon.swift  → writes assets/Gyroball.icns
import AppKit

let iconset = "assets/Gyroball.iconset"
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let sizes: [(px: Int, name: String)] = [
    (16, "16x16"), (32, "16x16@2x"),
    (32, "32x32"), (64, "32x32@2x"),
    (128, "128x128"), (256, "128x128@2x"),
    (256, "256x256"), (512, "256x256@2x"),
    (512, "512x512"), (1024, "512x512@2x"),
]

func render(px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
    else { return nil }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    defer { NSGraphicsContext.restoreGraphicsState() }

    let s = CGFloat(px)

    // macOS icon grid: squircle inset ~10% on each side
    let inset = s * 0.10
    let rect  = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path  = NSBezierPath(roundedRect: rect,
                             xRadius: rect.width * 0.225,
                             yRadius: rect.width * 0.225)

    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.04, green: 0.10, blue: 0.22, alpha: 1),
        NSColor(calibratedRed: 0.00, green: 0.48, blue: 0.65, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -60)

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.42, weight: .light)
    if let symbol = NSImage(systemSymbolName: "gyroscope", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let white = NSImage(size: symbol.size, flipped: false) { r in
            symbol.draw(in: r)
            NSColor.white.set()
            r.fill(using: .sourceAtop)
            return true
        }
        let symSize = NSSize(width: rect.width * 0.62,
                             height: rect.width * 0.62 * symbol.size.height / symbol.size.width)
        white.draw(in: NSRect(x: (s - symSize.width) / 2,
                              y: (s - symSize.height) / 2,
                              width: symSize.width,
                              height: symSize.height))
    }

    return rep.representation(using: .png, properties: [:])
}

for (px, name) in sizes {
    guard let png = render(px: px) else { fatalError("render failed at \(px)px") }
    try png.write(to: URL(fileURLWithPath: "\(iconset)/icon_\(name).png"))
}
print("✓ iconset written to \(iconset)")
