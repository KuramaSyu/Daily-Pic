//
//  OsuSettings.swift
//  Daily Pic
//
//  Created by Paul Zenker on 28.05.25.
//
import SwiftUI

class OsuSettings {
    static let shared = OsuSettings()
    
    var osuEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "osuEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "osuEnabled") }
    }
    
    var osuApiId: String {
        get { UserDefaults.standard.string(forKey: "osuApiId") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "osuApiId") }
    }
    
    var osuApiSecret: String {
        get { UserDefaults.standard.string(forKey: "osuApiSecret") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "osuApiSecret") }
    }
}
