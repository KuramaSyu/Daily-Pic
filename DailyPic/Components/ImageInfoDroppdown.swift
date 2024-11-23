//
//  ImageInfoDroppdown.swift
//  DailyPic
//
//  Created by Paul Zenker on 21.11.24.
//

import SwiftUI

struct DropdownWithToggles: View {
    @State private var isExpanded = false
    @State private var toggleOption1 = false
    @State private var toggleOption2 = true

    var bingImage: BingImage?
    var image: NamedImage
    
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .listRowSeparatorLeading) {
                Toggle("Option 1", isOn: $toggleOption1).toggleStyle(SwitchToggleStyle())
                Toggle("Option 2", isOn: $toggleOption2).toggleStyle(SwitchToggleStyle())
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
    }
    
    func getGroupText() -> String {
        return bingImage?.copyright ?? String(image.url.lastPathComponent)
    }
}
