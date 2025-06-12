//
//  OsuWallpaperApi.swift
//  Daily Pic
//
//  Created by Paul Zenker on 28.05.25.
//

import Foundation
struct OsuTokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

class OsuWallpaperApi: WallpaperApiProtocol {
    var osuSettings: OsuSettings
    var accessToken: OsuTokenResponse?
    
    init() {
        self.osuSettings = OsuSettings()
    }
    func downloadImage(of date: Date) async -> WallpaperResponse? {
        return nil
    }
    
    private func getSeasonalBackgrounds() async throws -> String {
        return ""
    }
    
    private func getAccessToken() async throws -> String {
        let url = URL(string: "https://osu.ppy.sh/oauth/token")
        
        // headers
        var request = URLRequest(url: url!)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // body
        var bodyParams = [
            "client_id": osuSettings.osuApiId,
            "client_secret": osuSettings.osuApiSecret,
            "grant_type": "client_credentials",
            "scope": "public"
        ]
        
        let bodyString = bodyParams
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
        
        request.httpBody = bodyString.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(OsuTokenResponse.self, from: data)
        self.accessToken = decoded
        return decoded.access_token
    }
}
