import AppKit
import Foundation

private let canvasSize = 1024
private let outputURL: URL = {
    guard CommandLine.arguments.count == 2 else {
        fatalError("Usage: generate-icon.swift OUTPUT.icns")
    }
    return URL(fileURLWithPath: CommandLine.arguments[1])
}()

private func roundedRect(_ rect: NSRect, radius: CGFloat, color: NSColor) {
    color.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

private func drawMeter(in rect: NSRect, progress: CGFloat, color: NSColor) {
    roundedRect(rect, radius: rect.height / 2, color: NSColor.white.withAlphaComponent(0.18))
    let fill = NSRect(x: rect.minX, y: rect.minY, width: rect.width * progress, height: rect.height)
    roundedRect(fill, radius: rect.height / 2, color: color)

    let indicatorDiameter = rect.height * 0.48
    let indicator = NSRect(
        x: fill.maxX - indicatorDiameter - rect.height * 0.25,
        y: rect.midY - indicatorDiameter / 2,
        width: indicatorDiameter,
        height: indicatorDiameter
    )
    roundedRect(indicator, radius: indicatorDiameter / 2, color: .white)
}

private func renderIcon(size: Int) throws -> Data {
    let logicalSize = NSSize(width: canvasSize, height: canvasSize)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw NSError(domain: "IconGenerator", code: 1)
    }
    bitmap.size = logicalSize

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "IconGenerator", code: 2)
    }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(origin: .zero, size: logicalSize).fill()

    let tile = NSRect(x: 92, y: 92, width: 840, height: 840)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 190, yRadius: 190)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.32)
    shadow.shadowBlurRadius = 42
    shadow.shadowOffset = NSSize(width: 0, height: -20)
    shadow.set()
    NSColor(calibratedRed: 0.04, green: 0.12, blue: 0.13, alpha: 1).setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let background = NSGradient(colors: [
        NSColor(calibratedRed: 0.04, green: 0.20, blue: 0.20, alpha: 1),
        NSColor(calibratedRed: 0.03, green: 0.10, blue: 0.12, alpha: 1),
    ])!
    background.draw(in: tilePath, angle: -55)

    NSColor.white.withAlphaComponent(0.14).setStroke()
    tilePath.lineWidth = 3
    tilePath.stroke()

    drawMeter(
        in: NSRect(x: 224, y: 566, width: 576, height: 120),
        progress: 0.54,
        color: NSColor(calibratedRed: 0.12, green: 0.83, blue: 0.62, alpha: 1)
    )
    drawMeter(
        in: NSRect(x: 224, y: 338, width: 576, height: 120),
        progress: 0.90,
        color: NSColor(calibratedRed: 1.00, green: 0.36, blue: 0.35, alpha: 1)
    )

    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 3)
    }
    return png
}

private let iconsetURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("Sub2APIMonitor-\(UUID().uuidString).iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: iconsetURL) }

private let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for variant in variants {
    let data = try renderIcon(size: variant.pixels)
    try data.write(to: iconsetURL.appendingPathComponent(variant.name), options: .atomic)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", outputURL.path, iconsetURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    throw NSError(domain: "IconGenerator", code: Int(process.terminationStatus))
}
