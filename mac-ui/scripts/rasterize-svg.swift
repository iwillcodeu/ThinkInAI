import AppKit
import Foundation

guard CommandLine.arguments.count >= 4,
      let pixels = Int(CommandLine.arguments[3])
else {
    FileHandle.standardError.write(Data("usage: rasterize-svg.swift <in.image> <out.png> <pixels>\n".utf8))
    exit(2)
}

let src = URL(fileURLWithPath: CommandLine.arguments[1])
let dest = URL(fileURLWithPath: CommandLine.arguments[2])
guard let image = NSImage(contentsOf: src) else {
    FileHandle.standardError.write(Data("failed to read \(src.path)\n".utf8))
    exit(1)
}

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: pixels,
    pixelsHigh: pixels,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    exit(1)
}

rep.size = NSSize(width: pixels, height: pixels)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high
NSGraphicsContext.current?.cgContext.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))

let canvas = CGFloat(pixels)
let srcSize = image.size
let scale = min(canvas / srcSize.width, canvas / srcSize.height)
let drawW = srcSize.width * scale
let drawH = srcSize.height * scale
image.draw(
    in: NSRect(
        x: (canvas - drawW) / 2,
        y: (canvas - drawH) / 2,
        width: drawW,
        height: drawH
    ),
    from: .zero,
    operation: .sourceOver,
    fraction: 1
)
NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    exit(1)
}

try png.write(to: dest)
