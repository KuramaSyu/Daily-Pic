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
        VStack(alignment: .leading) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading) {
                    Toggle("Option 1", isOn: $toggleOption1)

                    Toggle("Option 2", isOn: $toggleOption2)
                }
                .padding(.leading, 10) // Optional, for visual hierarchy
            } label: {
                Text(getGroupText())
                    .font(.headline)
                    .padding(6)
                    //.foregroundColor(.blue)
            }
            .padding(6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Display the values for demonstration
//            Text("Option 1 is \(toggleOption1 ? "ON" : "OFF")")
//            Text("Option 2 is \(toggleOption2 ? "ON" : "OFF")")
        }
        .padding()
    }
    
    func getGroupText() -> String {
        return bingImage?.copyright ?? String(image.url.lastPathComponent)
    }
}
