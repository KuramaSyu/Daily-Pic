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
        // Create a context to draw the scaled image
        guard let context = CGContext(
            data: nil,
            width: Int(scaledWidth),
            height: Int(scaledHeight),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: cgImage.bitmapInfo.rawValue
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
        
        // Create a CGImageSource from the file URL to handle the image data more efficiently
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            print("Failed to create image source from URL.")
            return nil
        }
        let nsImage: NSImage?
        
        if self.scale_factor != 1 {
            // Get the first image (for multi-image formats like GIF, TIFF, etc.)
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
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
