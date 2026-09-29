//
//  AccentColorStore.swift
//  Daily Pic
//
//  Singleton that derives a SwiftUI accent color from the current wallpaper
//  image. Updates fire from the menu when the gallery flips to a new picture
//  and from anywhere else that has access to an NSImage. Views that need the
//  current value attach via @ObservedObject; the value is also propagated as
//  a SwiftUI .tint() so built-in controls (toggles, sliders) follow along.
//

import SwiftUI
import AppKit
import ImageIO

@MainActor
final class AccentColorStore: ObservableObject {
    static let shared = AccentColorStore()

    /// Live accent color. Defaults to system accent until an image is sampled.
    @Published private(set) var color: Color = .accentColor

    /// URL of the image that produced the current color, for diagnostics.
    @Published private(set) var sourceImageURL: URL?

    /// Sampling side length in pixels for the dominant-color pass.
    /// 32 is plenty for an accent -- smaller than the typical 100k+ source
    /// image yet large enough to smooth out JPEG noise.
    private let sampleSize: Int = 32

    private init() {}

    /// Re-derive the accent color from the given image.
    /// Safe to call from any main-actor context. Sampling runs on the main
    /// actor too -- at 32x32 it is a sub-millisecond CGContext draw -- so we
    /// avoid the cross-actor Sendable dance entirely.
    func update(from image: NSImage?, url: URL? = nil) {
        sourceImageURL = url
        guard let image else { return }
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            color = .accentColor
            return
        }
        let computed = AccentColorStore.dominantColor(from: cgImage, side: sampleSize)
        color = computed
        RuntimeLog.write("accent updated url=\(url?.lastPathComponent ?? "nil")")
    }

    /// Sample a small bitmap of the image and return its mean RGB color,
    /// nudged toward higher saturation so the result reads as an accent
    /// rather than a muddy average of the whole wallpaper.
    nonisolated private static func dominantColor(from cgImage: CGImage, side: Int) -> Color {
        let space = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = side * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: side * side * bytesPerPixel)
        guard let context = CGContext(
            data: &pixels,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return .accentColor
        }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var rTotal: Double = 0
        var gTotal: Double = 0
        var bTotal: Double = 0
        let count = Double(side * side)
        for i in 0..<side * side {
            rTotal += Double(pixels[i * 4 + 0])
            gTotal += Double(pixels[i * 4 + 1])
            bTotal += Double(pixels[i * 4 + 2])
        }
        var r = rTotal / count / 255
        var g = gTotal / count / 255
        var b = bTotal / count / 255

        // Boost saturation toward 1 by pulling every channel toward grey,
        // so muted wallpapers (sky, fog) still yield a vivid accent.
        let grey = (r + g + b) / 3
        let saturationBoost: Double = 0.35
        r = grey + (r - grey) * (1 + saturationBoost)
        g = grey + (g - grey) * (1 + saturationBoost)
        b = grey + (b - grey) * (1 + saturationBoost)
        let clamp: (Double) -> Double = { min(max($0, 0), 1) }

        return Color(red: clamp(r), green: clamp(g), blue: clamp(b))
    }

    /// Pick black or white so foreground text stays legible over the accent.
    /// Uses the standard W3C relative-luminance contrast formula; threshold
    /// 0.55 errs on the lighter side for the saturated wallpapers DailyPic
    /// typically samples.
    nonisolated static func contrastColor(for color: Color) -> Color {
        let (r, g, b, _) = Self.rgba(from: color)
        return Self.luminance(r, g, b) > 0.55 ? Color.black : Color.white
    }

    /// Lighter, lower-saturation wash derived from the live accent.
    /// Drops saturation ~40% and lifts the channels toward white so the
    /// result reads as a subtle hover background rather than a saturated
    /// block of color.
    nonisolated static func lighterWash(for color: Color, mix: Double = 0.65) -> Color {
        let (r, g, b, _) = Self.rgba(from: color)
        let wash: (Double) -> Double = { channel in
            let grey = (r + g + b) / 3
            let desaturated = grey + (channel - grey) * 0.4
            return channel * (1 - mix) + desaturated * mix
        }
        let clamp: (Double) -> Double = { min(max($0, 0), 1) }
        return Color(red: clamp(wash(r)), green: clamp(wash(g)), blue: clamp(wash(b)))
    }

    nonisolated private static func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
        let linearize: (Double) -> Double = { c in
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    nonisolated private static func rgba(from color: Color) -> (Double, Double, Double, Double) {
        #if canImport(AppKit)
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        return (
            Double(ns.redComponent),
            Double(ns.greenComponent),
            Double(ns.blueComponent),
            Double(ns.alphaComponent)
        )
        #else
        return (0, 0, 0, 1)
        #endif
    }
}