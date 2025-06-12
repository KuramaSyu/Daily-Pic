//
//  OsuSettingsStore.swift
//  Daily Pic
//
//  Created by Paul Zenker on 12.06.25.
//
import SwiftUI
import Combine

class OsuSettingsStore: ObservableObject {
    @Published var isEnabled: Bool {
        didSet {UserDefaults.standard.set(isEnabled, forKey: "osuEnabled")}
    }
    
    @Published var apiId: String {
        didSet {UserDefaults.standard.set(apiId, forKey: "osuApiId")}
    }
    
    @Published var apiSecret: String {
        didSet {UserDefaults.standard.set(apiSecret, forKey: "osuApiSecret")}
    }
    
    init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "osuEnabled")
        self.apiId = UserDefaults.standard.string(forKey: "osuApiId") ?? ""
        self.apiSecret = UserDefaults.standard.string(forKey: "osuApiSecret") ?? ""
    }
}
