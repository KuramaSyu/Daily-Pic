//
//  ImageInfoDroppdown.swift
//  DailyPic
//
//  Created by Paul Zenker on 21.11.24.
//

import SwiftUI
import LaunchAtLogin

struct DropdownWithToggles: View {
    var bingImage: BingImage?
    var image: NamedImage
    var imageManager: ImageManager
    
    @State private var isExpanded = false
    @State private var toggleOption1 = false
    @State private var toggleOption2 = true
    
    @State private var set_wallpaper_on_navigation: Bool = false {
        didSet {
            print("set_wallpaper_on_navigation: \(set_wallpaper_on_navigation)")
            imageManager.config?.toggles.set_wallpaper_on_navigation = set_wallpaper_on_navigation
            imageManager.writeConfig()
        }
    }
    
    @State private var shuffle_favorites_only: Bool = false {
        didSet {
            imageManager.config?.toggles.shuffle_favorites_only = shuffle_favorites_only
            imageManager.writeConfig()
        }
    }


    
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .listRowSeparatorLeading) {
                LaunchAtLogin.Toggle("Autostart").toggleStyle(SwitchToggleStyle())
                Toggle("Only shuffle through favorites", isOn: $shuffle_favorites_only).toggleStyle(SwitchToggleStyle())
                Toggle("Set wallpaper directly", isOn: $set_wallpaper_on_navigation).toggleStyle(SwitchToggleStyle())
            }
            .onChange(of: shuffle_favorites_only) {
                print("changed shuffle_favorites_only to \(shuffle_favorites_only)")
                imageManager.config?.toggles.shuffle_favorites_only = shuffle_favorites_only
                imageManager.writeConfig()
            }
            .onChange(of: set_wallpaper_on_navigation) {
                print("changed set_wallpaper_on_navigation to \(set_wallpaper_on_navigation)")
                imageManager.config?.toggles.set_wallpaper_on_navigation = set_wallpaper_on_navigation
                imageManager.writeConfig()
            }
        }
        label: {
            Text(getGroupText())
                .font(.headline)
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
    }
    
    func loadFromConfig() {
        set_wallpaper_on_navigation = imageManager.config!.toggles.set_wallpaper_on_navigation
        shuffle_favorites_only = imageManager.config!.toggles.shuffle_favorites_only
    }
    func getGroupText() -> String {
        return bingImage?.copyright ?? String(image.url.lastPathComponent)
    }
}
