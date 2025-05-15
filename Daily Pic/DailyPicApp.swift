//
//  DailyPicApp.swift
//  DailyPic
//
//  Created by Paul Zenker on 17.11.24.
//
import SwiftUI
import AppKit
import ImageIO

class DateParser {
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
    
    static let regex: NSRegularExpression? = {
        let pattern = "\\d{8}"
        return try? NSRegularExpression(pattern: pattern)
    }()
    
    static func ordinalSuffix(for date: Date) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let day = calendar.component(.day, from: date)
        switch day % 10 {
        case 1 where day != 11: return "st"
        case 2 where day != 12: return "nd"
        case 3 where day != 13: return "rd"
        default: return "th"
        }
    }
    
    // Added function to centralize date formatting for views
    static func prettyDate(for date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d'\(ordinalSuffix(for: date))' MMMM"
        return outputFormatter.string(from: date)
    }
}


public class NamedImage: Hashable, CustomStringConvertible  {
    let url: URL
    let creation_date: Date
    var metadata: BingImage?
    var image: NSImage?
    
    init(url: URL, creation_date: Date, image: NSImage? = nil) {
        self.url = url
        self.creation_date = creation_date
    }

    func exists() -> Bool {
        print("check path: \(url.path(percentEncoded: false))")
        return FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }
    /// get metadata form metadata/YYYYMMDD_name.json
    /// and store it in .metadata. Can fail
    /// needs the
    func getMetaData() {
        // strip _UHD.jpeg from image
        let metadata_dir = GalleryModel.shared.metadataPath
        if metadata != nil { return }
        let image_name = String(url.lastPathComponent.removingPercentEncoding!.split(separator: "_UHD").first!)
        let metadata_path = metadata_dir.appendingPathComponent("\(image_name).json")
        let metadata = try? JSONDecoder().decode(BingImage.self, from: Data(contentsOf: metadata_path))
        if let metadata = metadata {
            self.metadata = metadata
            print("loaded Metadata for \(metadata.title)")
        } else {
            print("failed to load metadata from \(metadata_path)")
        }
    }
    
    // Implement the required `==` operator for equality comparison
    public static func ==(lhs: NamedImage, rhs: NamedImage) -> Bool {
        return lhs.url.lastPathComponent == rhs.url.lastPathComponent
    }

    // Implement the required `hash(into:)` method
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url.lastPathComponent)
    }
    
    // Implement the description property for custom printing
    public var description: String {
        return "NamedImage(url: \(url))"
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    func getDate() -> Date {
        let string: String = metadata?.enddate ?? String(url.lastPathComponent)
        var parsedDate: Date = creation_date
        if let extracted_date = _stringToDate(from: string) {
            parsedDate = extracted_date
        }
        return parsedDate
    }
    
    
    func loadNSImage() -> NSImage? {
        let scale_factor = CGFloat(0.2)
        return ImageLoader(url: self.url, scale_factor: scale_factor).getImage()
    }
    
    
    func unloadImage() {
        self.image = nil
    }
    /// loads image without RAM footprint
    func loadCGImage() -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        defer { print("Image loaded temporarily, will not be stored in memory.") }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    
    /// Format the date to "24th November" format
    func prettyDate(from date: Date) -> String {
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d'\(DateParser.ordinalSuffix(for: date))' MMMM"
        return outputFormatter.string(from: date)
    }
    
    /// converts a string containing yyyyMMdd to a Date object
    func _stringToDate(from string: String) -> Date? {
        let dateFormatter = DateParser.dateFormatter
        guard let regex = DateParser.regex else { return nil }
        
        let range = NSRange(location: 0, length: string.utf16.count)
        if let match = regex.firstMatch(in: string, options: [], range: range),
           let matchRange = Range(match.range, in: string) {
            let datePart = String(string[matchRange])
            return dateFormatter.date(from: datePart)
        }
        return nil
    }
}


// MARK: DailyPicApp
@main
struct DailyPicApp: App {
    // 2 variables to set default focus https://developer.apple.com/documentation/swiftui/view/prefersdefaultfocus(_:in:)
    @Namespace var mainNamespace
    @Environment(\.resetFocus) var resetFocus
    
    @ObservedObject var imageManager = GalleryViewModel.getInstance()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let menuIcon: NSImage = {
        let ratio = $0.size.height / $0.size.width
        $0.size.height = 18
        $0.size.width = 18 / ratio
        return $0
    }(NSImage(named: "Aurora Walls Mono")!)
    
    var body: some Scene {
        MenuBarExtra() {
            // Title
            Text(self.getTitleText())
                .font(.headline)
                .padding(.top, 15)
            if let metadata = imageManager.currentImage?.metadata {
                Text(metadata.title)
                    .font(.subheadline)
            }
            
            if let nextImage = imageManager.revealNextImage {
                RevealNextImageView(revealNextImage: nextImage)
                    .transition(.opacity.combined(with: .scale)) // Add transition effect
                    .animation(.easeInOut(duration: 0.8), value: (imageManager.revealNextImage != nil))
            }            // Image Data
            VStack() {
                if let current_image = imageManager.currentImage {
                    DropdownWithToggles(
                        bingImage: current_image.metadata, image: current_image,
                        imageManager: imageManager
                    )
                    // Image Preview
                    if let loaded_image = current_image.loadNSImage() {
                        Image(nsImage: loaded_image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(20)
                            .shadow(radius: 3)
                            // Adding a tap gesture to open the image in an image viewer
                            .onTapGesture {
                                openInViewer(url: current_image.url)
                            }
                    }
                } else {
                    VStack(alignment: .center) {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.icloud")
                            .resizable()
                            .scaledToFit()
                            .frame(minWidth: 50, minHeight: 50)
                            .padding(.top, 10)
                        Text("No image available.")
                            .font(.headline)
                            .padding(10)
                        Text("Downloading images from last 7 days...")
                            .font(.headline)
                            .padding(10)
                    }
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200, alignment: .center)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                
                ImageNavigation(imageManager: imageManager)
                    .scaledToFit()  // make it not overflow the box
                
                QuickActions(imageManager: imageManager)
                    .layoutPriority(2)
                    .padding(.bottom, 10)
            }
            .padding(.horizontal, 15)
            .frame(width: 350, height: 450)
            .focusScope(mainNamespace)
            .onAppear {
                Task {await BingImageTracker.shared.downloadMissingImages()}
            }
            .focusEffectDisabled(true)
            .onDisappear {
                imageManager.onDisappear();
            }
        } label: {
            Image(nsImage: menuIcon)
        }
        .menuBarExtraStyle(.window)
    }
    
    func getTitleText() -> String {
        let wrap_text = { (date: String) in return "Picture of \(date)" }
        
        guard let image = imageManager.currentImage else {
            // use DateParser for date formatting
            return wrap_text(DateParser.prettyDate(for: Date()))
        }
        return wrap_text(DateParser.prettyDate(for: image.getDate()))
    }
    
    private func openInViewer(url: URL) {
        NSWorkspace.shared.open(url)
    }
    
    func loadPreviousBingImages() {
        Task {
            
            let dates = await BingImageTracker.shared.downloadMissingImages()
            await MainActor.run {
                print("downloaded bing wallpapers from these days: \(dates)")
                
                // save the url of the current image
                let current_image_url = imageManager.currentImage?.url
                
                // reload images
                imageManager.loadImages()
                
                // set index where last picture is now
                if let url = current_image_url {
                    imageManager.setIndexByUrl(url)
                }
            }
        }
    }
}



extension Array {
    func element(at index: Int, default defaultValue: Element) -> Element {
        return indices.contains(index) ? self[index] : defaultValue
    }
}



