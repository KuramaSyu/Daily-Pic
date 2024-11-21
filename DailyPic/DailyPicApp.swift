//
//  DailyPicApp.swift
//  DailyPic
//
//  Created by Paul Zenker on 17.11.24.
//
import SwiftUI

class NamedImage: Hashable, CustomStringConvertible  {
    var image: NSImage?
    let url: URL
    let creation_date: Date
    var metadata: BingImage?
    
    init(url: URL, creation_date: Date, image: NSImage? = nil) {
        if let image {
            self.image = image
        }
        self.url = url
        self.creation_date = creation_date
    }
    
    /// get metadata form metadata/YYYYMMDD_name.json
    /// and store it in .metadata. Can fail 
    func getMetaData(from metadata_dir: URL) {
        // strip _UHD.jpeg from image
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
    static func ==(lhs: NamedImage, rhs: NamedImage) -> Bool {
        return lhs.url.lastPathComponent == rhs.url.lastPathComponent
    }

    // Implement the required `hash(into:)` method
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.lastPathComponent)
    }
    
    // Implement the description property for custom printing
    var description: String {
        return "NamedImage(url: \(url))"
    }
    
    func getDate() -> Date {
        let string: String = metadata?.startdate ?? String(url.lastPathComponent)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd" // Format of the date in the string
        
        var parsedDate: Date = creation_date
        
        // parse the string
        if let extracted_date = _stringToDate(from: string) {
            parsedDate = extracted_date
        }

        return parsedDate
    }
    
    /// Format the date to "24th November" format
    func prettyDate(from date: Date) -> String {
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d'\(ordinalSuffix(for: date))' MMMM"
        return outputFormatter.string(from: date)
    }
    
    /// converts a string containing yyyyMMdd to a Date object
    func _stringToDate(from string: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd" // Format of the date in the string
        
        // Extract date string from the input
        let pattern = "\\d{8}" // Matches 8-digit sequences (YYYYMMDD)
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: string.utf16.count)
        
        if let match = regex?.firstMatch(in: string, options: [], range: range),
           let matchRange = Range(match.range, in: string) {
            let datePart = String(string[matchRange])
            return dateFormatter.date(from: datePart)
        }
        return nil
    }
    
    // Helper function to determine the ordinal suffix for a day
    func ordinalSuffix(for date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        switch day % 10 {
        case 1 where day != 11: return "st"
        case 2 where day != 12: return "nd"
        case 3 where day != 13: return "rd"
        default: return "th"
        }
    }
}


class WakeObserver {
    private var onWake: () -> Void
    
    init(onWake: @escaping () -> Void) {
        self.onWake = onWake
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWakeNotification),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLaunchNotification),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
    }
    
    @objc private func handleWakeNotification() {
        print("Handle Wake")
        onWake()
    }
    
    @objc private func handleLaunchNotification() {
        print("Handle Launch")
        onWake()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}





@main
struct DailyPicApp: App {
    @Namespace var mainNamespace
    @State var currentNumber: String = "1" // Example state variable
    @StateObject private var imageManager = ImageManager()
    @State private var wakeObserver: WakeObserver?
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @FocusState private var dummyFocus: Bool?


    var body: some Scene {
        MenuBarExtra("DailyPic", systemImage: "photo") {
            VStack(alignment: .center) {
                Text(self.getTitleText())
                    .font(.headline)
                    .padding(3)
                Divider()
                    .padding(.bottom, 1)
                
                if let current_image = imageManager.currentImage {
                    DropdownWithToggles(
                        bingImage: imageManager.currentImage?.metadata, image: current_image
                    )
                }

                // Image Preview
                if let current_image = imageManager.currentImage {
                        Image(nsImage: current_image.image!)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(20)
                        .shadow(radius: 3)
                        .layoutPriority(2)
                        .padding(.horizontal, 3)
                        .prefersDefaultFocus(in: mainNamespace)
                } else {
                    Text("No image available")
                        .padding()
                        
                }
                
                HStack(spacing: 3) {
                    
                    // Backward Button
                    Button(action: {
                        imageManager.showPreviousImage()
                    }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    //.frame(minWidth: 10, maxWidth: .infinity)
                    .scaledToFill()
                    .layoutPriority(1)
                    .buttonStyle(.borderless)
                    .hoverEffect()
                    
                    
                    // Favorite Button
                    Button(action: {imageManager.makeFavorite()}) {
                        Image(
                            systemName: imageManager.isCurrentFavorite() ? "star.fill" : "star"
                        )
                        .frame(maxWidth: .infinity, minHeight: 30)
                            .font(.title2)
                    }
                    //.frame(minWidth: 10, maxWidth: .infinity)
                    .scaledToFill()
                    .buttonStyle(.borderless)
                    .layoutPriority(1)
                    .hoverEffect()
                    
                    // Forward Button
                    Button(action: {
                        imageManager.showNextImage()
                    }) {
                        Image(systemName: "arrow.right")
                            .font(.title2)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    //.frame(minWidth: 10, maxWidth: .infinity)
                    .scaledToFill()
                    .layoutPriority(1)
                    .buttonStyle(.borderless)
                    .hoverEffect()
                }
                .padding(.vertical, 1)
                .padding(.horizontal, 1)
                .scaledToFill()

                // Menu
                QuickActions(imageManager: imageManager)
            }
            .padding(10) // Adds padding to make it look better
            .frame(width: 350, height: 550) // Adjust width to fit the buttons
            .onAppear {
                dummyFocus = nil // Clear any default focus
                imageManager.initialsize_environment()
                imageManager.loadImages()
                imageManager.loadCurrentImage()
                imageManager.runDailyTaskIfNeeded()
            }
            .scaledToFill()
            
 
        }
        .menuBarExtraStyle(.window)
    }
    
    func getTitleText() -> String {
        if let image = imageManager.currentImage {
            var string = String()
            if let metadata = image.metadata {
                string = _formatDate(or: metadata.startdate)!
            } else {
                string = _formatDate(or: String(image.url.lastPathComponent))!
            }
            return string
        }
        return _formatDate(from: Date())!
    }
    
    func _formatDate(from date: Date? = nil, or string: String? = nil) -> String? {
        guard date != nil || string != nil else {
            print("Error: Either a date or a string must be provided.")
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd" // Format of the date in the string
        
        var parsedDate: Date?
        
        // Use the provided date if available
        if let date = date {
            parsedDate = date
        }
        // Otherwise, parse the string
        else if let string = string {
            // Extract date string from the input
            let pattern = "\\d{8}" // Matches 8-digit sequences (YYYYMMDD)
            let regex = try? NSRegularExpression(pattern: pattern)
            let range = NSRange(location: 0, length: string.utf16.count)
            
            if let match = regex?.firstMatch(in: string, options: [], range: range),
               let matchRange = Range(match.range, in: string) {
                let datePart = String(string[matchRange])
                parsedDate = dateFormatter.date(from: datePart)
            }
        }
        
        // If no valid date is parsed
        guard let finalDate = parsedDate else {
            print("Error: Unable to parse date from input.")
            return nil
        }
        
        // Format the date to "24th November" format
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "d'\(ordinalSuffix(for: finalDate))' MMMM"
        return outputFormatter.string(from: finalDate)
    }
    
    // Helper function to determine the ordinal suffix for a day
    func ordinalSuffix(for date: Date) -> String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: date)
        switch day % 10 {
        case 1 where day != 11: return "st"
        case 2 where day != 12: return "nd"
        case 3 where day != 13: return "rd"
        default: return "th"
        }
    }
    

}





extension Array {
    func element(at index: Int, default defaultValue: Element) -> Element {
        return indices.contains(index) ? self[index] : defaultValue
    }
}

struct Config: Codable {
    var favorites: Set<String>
    var languages: [String]  // index 0 for first Workspace, 1 for 2nd, 2 for 3rd ...
}
