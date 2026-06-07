#!/usr/bin/env swift
import Foundation
import AppKit

let assetRoot = "/Users/paulcarroll/Dev/anon/stashtv/StashTV/Assets.xcassets/App Icon & Top Shelf Image.brandassets"

func renderPNG(width: Int, height: Int, draw: () -> Void) -> Data {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: width, height: height)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    draw()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("PNG generation failed (\(width)x\(height))")
    }
    return data
}

func savePNG(_ data: Data, to path: String) {
    try! data.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path)")
}

func drawBackgroundGradient(size: NSSize) {
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.06, green: 0.20, blue: 0.24, alpha: 1.0),
        NSColor(srgbRed: 0.02, green: 0.06, blue: 0.08, alpha: 1.0),
    ])!
    gradient.draw(in: NSRect(origin: .zero, size: size), angle: 270)
}

func drawPlayTriangle(size: NSSize, opacity: CGFloat) {
    let triHeight = size.height * 0.62
    let triWidth = triHeight * 0.866
    let cx = size.width / 2
    let cy = size.height / 2

    NSColor(srgbRed: 0.10, green: 0.92, blue: 0.82, alpha: opacity).setFill()
    let path = NSBezierPath()
    path.move(to: NSPoint(x: cx - triWidth * 0.35, y: cy + triHeight / 2))
    path.line(to: NSPoint(x: cx - triWidth * 0.35, y: cy - triHeight / 2))
    path.line(to: NSPoint(x: cx + triWidth * 0.55, y: cy))
    path.close()
    path.fill()
}

func drawWordmark(size: NSSize, fontFraction: CGFloat) {
    let baseFontSize = size.height * fontFraction
    let font = NSFont.systemFont(ofSize: baseFontSize, weight: .heavy)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white,
        .kern: -baseFontSize * 0.04,
    ]
    let attrString = NSAttributedString(string: "stash-tv", attributes: attrs)
    let textSize = attrString.size()
    attrString.draw(at: NSPoint(
        x: (size.width - textSize.width) / 2,
        y: (size.height - textSize.height) / 2 - baseFontSize * 0.05
    ))
}

func renderBack(width: Int, height: Int) -> Data {
    let size = NSSize(width: width, height: height)
    return renderPNG(width: width, height: height) {
        drawBackgroundGradient(size: size)
    }
}

func renderMiddle(width: Int, height: Int) -> Data {
    let size = NSSize(width: width, height: height)
    return renderPNG(width: width, height: height) {
        drawPlayTriangle(size: size, opacity: 0.32)
    }
}

func renderFront(width: Int, height: Int) -> Data {
    let size = NSSize(width: width, height: height)
    return renderPNG(width: width, height: height) {
        drawWordmark(size: size, fontFraction: 0.28)
    }
}

func renderTopShelf(width: Int, height: Int) -> Data {
    let size = NSSize(width: width, height: height)
    return renderPNG(width: width, height: height) {
        drawBackgroundGradient(size: size)

        let triHeight = size.height * 0.55
        let triWidth = triHeight * 0.866
        let triCX = size.width * 0.28
        let triCY = size.height / 2
        NSColor(srgbRed: 0.10, green: 0.92, blue: 0.82, alpha: 0.22).setFill()
        let tri = NSBezierPath()
        tri.move(to: NSPoint(x: triCX - triWidth * 0.4, y: triCY + triHeight / 2))
        tri.line(to: NSPoint(x: triCX - triWidth * 0.4, y: triCY - triHeight / 2))
        tri.line(to: NSPoint(x: triCX + triWidth * 0.6, y: triCY))
        tri.close()
        tri.fill()

        let baseFontSize = size.height * 0.34
        let font = NSFont.systemFont(ofSize: baseFontSize, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .kern: -baseFontSize * 0.04,
        ]
        let attrString = NSAttributedString(string: "stash-tv", attributes: attrs)
        let textSize = attrString.size()
        attrString.draw(at: NSPoint(
            x: size.width * 0.42,
            y: (size.height - textSize.height) / 2
        ))
    }
}

// Small App Icon (1x = 400x240, 2x = 800x480)
savePNG(renderBack(width: 400, height: 240),     to: "\(assetRoot)/App Icon.imagestack/Back.imagestacklayer/Content.imageset/back-1x.png")
savePNG(renderBack(width: 800, height: 480),     to: "\(assetRoot)/App Icon.imagestack/Back.imagestacklayer/Content.imageset/back-2x.png")
savePNG(renderMiddle(width: 400, height: 240),   to: "\(assetRoot)/App Icon.imagestack/Middle.imagestacklayer/Content.imageset/middle-1x.png")
savePNG(renderMiddle(width: 800, height: 480),   to: "\(assetRoot)/App Icon.imagestack/Middle.imagestacklayer/Content.imageset/middle-2x.png")
savePNG(renderFront(width: 400, height: 240),    to: "\(assetRoot)/App Icon.imagestack/Front.imagestacklayer/Content.imageset/front-1x.png")
savePNG(renderFront(width: 800, height: 480),    to: "\(assetRoot)/App Icon.imagestack/Front.imagestacklayer/Content.imageset/front-2x.png")

// App Store Icon (1x = 1280x768, 2x = 2560x1536)
savePNG(renderBack(width: 1280, height: 768),    to: "\(assetRoot)/App Icon - App Store.imagestack/Back.imagestacklayer/Content.imageset/back-1x.png")
savePNG(renderBack(width: 2560, height: 1536),   to: "\(assetRoot)/App Icon - App Store.imagestack/Back.imagestacklayer/Content.imageset/back-2x.png")
savePNG(renderMiddle(width: 1280, height: 768),  to: "\(assetRoot)/App Icon - App Store.imagestack/Middle.imagestacklayer/Content.imageset/middle-1x.png")
savePNG(renderMiddle(width: 2560, height: 1536), to: "\(assetRoot)/App Icon - App Store.imagestack/Middle.imagestacklayer/Content.imageset/middle-2x.png")
savePNG(renderFront(width: 1280, height: 768),   to: "\(assetRoot)/App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/front-1x.png")
savePNG(renderFront(width: 2560, height: 1536),  to: "\(assetRoot)/App Icon - App Store.imagestack/Front.imagestacklayer/Content.imageset/front-2x.png")

// Top Shelf (1x = 1920x720, 2x = 3840x1440)
savePNG(renderTopShelf(width: 1920, height: 720),  to: "\(assetRoot)/Top Shelf Image.imageset/topshelf-1x.png")
savePNG(renderTopShelf(width: 3840, height: 1440), to: "\(assetRoot)/Top Shelf Image.imageset/topshelf-2x.png")

// Top Shelf Wide (1x = 2320x720, 2x = 4640x1440)
savePNG(renderTopShelf(width: 2320, height: 720),  to: "\(assetRoot)/Top Shelf Image Wide.imageset/topshelf-wide-1x.png")
savePNG(renderTopShelf(width: 4640, height: 1440), to: "\(assetRoot)/Top Shelf Image Wide.imageset/topshelf-wide-2x.png")

print("Done.")
