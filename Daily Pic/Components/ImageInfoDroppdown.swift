//
//  ImageInfoDroppdown.swift
//  DailyPic
//
//  Created by Paul Zenker on 21.11.24.
//

import SwiftUI
import LaunchAtLogin


// Define a custom blurple color (Discord's blurple: #5865F2)
extension Color {
    static let dark_blurple = Color(red: 69/255.0, green: 79/255.0, blue: 191/255.0)
    static let blurple = Color(red: 88/255.0, green: 101/255.0, blue: 242/255.0)
}


struct DropdownWithToggles: View {
    var image: any NamedImageProtocol
    var imageManager: any GalleryViewModelProtocol
    
    @State private var isExpanded = false
    
    @State private var set_wallpaper_on_navigation: Bool = false
    
    @State private var shuffle_favorites_only: Bool = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .listRowSeparatorLeading) {
                HStack {
                    Text("Autostart")
                    Spacer()
                    LaunchAtLogin.Toggle("")
                        .toggleStyle(SwitchToggleStyle())
                        .accentColor(Color.blurple)
                }
                .padding(.horizontal)

                // Only shuffle through favorites toggle
                HStack {
                    Text("Only shuffle through favorites")
                    Spacer()
                    Toggle("", isOn: $shuffle_favorites_only)
                        .toggleStyle(SwitchToggleStyle())
                        .accentColor(Color.blurple)
                }
                .padding(.horizontal)

                // Set wallpaper directly toggle
                HStack {
                    Text("Set wallpaper directly")
                    Spacer()
                    Toggle("", isOn: $set_wallpaper_on_navigation)
                        .toggleStyle(SwitchToggleStyle())
                        .accentColor(Color.blurple)
                }
                .padding(.horizontal)
            }
            .onChange(of: shuffle_favorites_only) {
                if imageManager.config.toggles.shuffle_favorites_only == shuffle_favorites_only {
                    return
                }
                print("changed shuffle_favorites_only to \(shuffle_favorites_only)")
                imageManager.config.toggles.shuffle_favorites_only = shuffle_favorites_only
                imageManager.writeConfig()
            }
            .onChange(of: set_wallpaper_on_navigation) {
                if imageManager.config.toggles.set_wallpaper_on_navigation == set_wallpaper_on_navigation {
                    return
                }
                print("changed set_wallpaper_on_navigation to \(set_wallpaper_on_navigation)")
                imageManager.config.toggles.set_wallpaper_on_navigation = set_wallpaper_on_navigation
                imageManager.writeConfig()
            }
        }
        label: {
            VStack(alignment: .leading, spacing: 2) {
                let texts = splitCopyright(input: getGroupText())
                Text(texts.0)
                    .font(.headline) // Picture Title
                    .foregroundColor(.primary)
                if texts.1.count > 0 {
                    Text(texts.1) // Picture Copyright
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(2)
            .padding(.leading, 6)
        }
        .padding(.vertical, 6)  // padding from last toggle to bottom
        .padding(.leading, 10)  // padding at left for >
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .contentShape(Rectangle()) // Makes the entire label tappable
        .onTapGesture {
            withAnimation { isExpanded.toggle() }
        }
        .padding(.bottom, 10)
        .onAppear {
            loadFromConfig()
        }
        .onDisappear {
            isExpanded = false
        }
    }
    
    func loadFromConfig() {
        set_wallpaper_on_navigation = imageManager.config.toggles.set_wallpaper_on_navigation
        shuffle_favorites_only = imageManager.config.toggles.shuffle_favorites_only
    }
    func getGroupText() -> String {
        return bingImage?.copyright ?? String(image.url.lastPathComponent)
    }
    
    func splitCopyright(input: String) -> (String, String) {
        if !input.contains("©") {
            return (input, "")
        }
        
        let pattern = "(.*)\\((©.*)\\)"
        
        // extract (title; copyright) from string
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            if let match = regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) {
                let firstPart = Range(match.range(at: 1), in: input).map { String(input[$0]) } ?? ""
                let secondPart = Range(match.range(at: 2), in: input).map { String(input[$0]) } ?? ""
                return (firstPart, secondPart)
            }
        } catch {
            print("Invalid regex: \(error)")
        }
        return (input, "")
    }
}
