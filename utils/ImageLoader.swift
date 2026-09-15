//
//  LoadPicture.swift
//  Daily Pic
//
//  Created by Paul Zenker on 21.01.25.
//
import SwiftUI
import AppKit
import ImageIO


class ImageLoader {
    let url: URL
    let scale_factor: CGFloat;
    
    init(url: URL, scale_factor: CGFloat = 1) {
        self.url = url
        self.scale_factor = scale_factor
    }
    
    func getImageScaling(cgImage: CGImage) -> (width: CGFloat, height: CGFloat) {
        // Calculate the scaled dimensions (0.2)
        let originalWidth = CGFloat(cgImage.width)
        let originalHeight = CGFloat(cgImage.height)
        let scaledWidth = originalWidth * scale_factor
        let scaledHeight = originalHeight * scale_factor
        print("Original: \(originalWidth) x \(originalHeight)")
        print("Scaled: \(scaledWidth) x \(scaledHeight)")
        return (width: scaledWidth, height: scaledHeight)
    }
    func rescaleImage(cgImage: CGImage, scaledWidth: CGFloat, scaledHeight: CGFloat) -> CGImage? {
        // Force a canonical sRGB destination so the embedded ICCv4 profile
        // (commonly 'sRGB ImageOptim.com') does not trigger ColorSync's
        // "tags 'rXYZ' and 'desc' overlap" warning on every re-decode.
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let alphaInfo: CGImageAlphaInfo = cgImage.alphaInfo == .none
            ? .noneSkipLast
            : .premultipliedFirst
        let bitmapInfo = alphaInfo.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        guard let context = CGContext(
            data: nil,
            width: Int(scaledWidth),
            height: Int(scaledHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: space,
            bitmapInfo: bitmapInfo
        ) else {
            print("Failed to create CGContext for scaling.")
            return nil
        }

        // Draw the scaled image
        context.interpolationQuality = .default // Set the interpolation quality for smoother scaling
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: scaledWidth, height: scaledHeight))

        // Create a new CGImage from the context
        guard let scaledCGImage = context.makeImage() else {
            print("Failed to create scaled CGImage.")
            return nil
        }

        return scaledCGImage
    }
        
    
        
    func getImage() -> NSImage? {

        // Strip the embedded ICC profile at decode time so we never feed
        // 'sRGB ImageOptim.com' (or any other ICCv4 profile with overlapping
        // rXYZ/desc tags) into ColorSync. The downstream CGContext will draw
        // in canonical sRGB, which is what we want anyway for a wallpaper
        // preview thumbnail.
        // The SkipMetadata key is exposed as a CFString constant on macOS;
        // the Swift overlay renames it, so use the string form to be safe.
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldAllowFloat: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            ("kCGImageSourceSkipMetadata" as CFString): true
        ]

        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else {
            print("Failed to create image source from URL.")
            return nil
        }
        let nsImage: NSImage?

        if self.scale_factor != 1 {
            // Get the first image (for multi-image formats like GIF, TIFF, etc.)
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, sourceOptions as CFDictionary) else {
                print("Failed to create CGImage from image source.")
                return nil
            }

            let new_dimensions = self.getImageScaling(cgImage: cgImage)
            let scaledWidth = new_dimensions.width
            let scaledHeight = new_dimensions.height

            guard let scaledImage = self.rescaleImage(cgImage: cgImage, scaledWidth: scaledWidth, scaledHeight: scaledHeight) else {
                return nil
            }

            // Convert the scaled CGImage to NSImage
            nsImage = NSImage(cgImage: scaledImage, size: NSSize(width: scaledWidth, height: scaledHeight))
        } else {
            nsImage = NSImage(contentsOf: url)
        }

        return nsImage
    }
}
