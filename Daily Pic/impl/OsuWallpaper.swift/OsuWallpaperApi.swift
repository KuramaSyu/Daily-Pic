//
//  OsuWallpaperApi.swift
//  Daily Pic
//
//  Created by Paul Zenker on 28.05.25.
//

import Foundation
import os

struct OsuTokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

class OsuWallpaperApi: WallpaperApiProtocol {
    var osuSettings: OsuSettings
    var accessToken: OsuTokenResponse?
    var json_cache: [String: BingApiResponse] = [:]
    let base_api: String = "https://osu.ppy.sh/api/v2"
    private let logger: Logger = Logger(subsystem: "OsuWallpaperApi", category: "network")


    init() {
        self.osuSettings = OsuSettings()
    }
    
    /// downlaods seasonal osu wallpapers via GET from /seasonal-backgrounds
    /// date parameter does not matter. it's only to comply to the interface
    func fetchResponse(of date: Date) async throws -> WallpaperResponse? {
        let api_response = try await getSeasonalBackgrounds()
        return OsuWallpaperAdapter(api_response)
    }
    
    /// Fetches JSON from osu! seasonal API
    func fetchJSON(from url: URL, headers: [String: String]? = nil) async throws -> OsuSeasonalBackgroundsResponse? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let headers = headers ?? [:]
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        do {
            let response = try JSONDecoder().decode(OsuSeasonalBackgroundsResponse.self, from: data)
            return response
        } catch {
            throw error
        }
    }
    
    private func getAccessToken() async throws -> OsuTokenResponse {
        if self.accessToken != nil {
            return self.accessToken!
        }
        let _ = try await getAccessToken();
        return self.accessToken!
    }
    
    private func getSeasonalBackgrounds() async throws -> OsuSeasonalBackgroundsResponse {
        let endpoint = "/seasonal-backgrounds"
        let access_token = accessToken?.access_token ?? "";
        let _headers = ["Authorization": "Bearer \(access_token)", "Accept": "application/json"]
        let response = try await fetchJSON(from: URL(string: base_api + endpoint)!)
        if response == nil {
            self.logger.warning("Osu wallpaper response was nil")
        }
        return response!
    }
    
    private func fetchAccessToken() async throws -> String {
        let url = URL(string: "https://osu.ppy.sh/oauth/token")
        
        // headers
        var request = URLRequest(url: url!)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // body
        let bodyParams = [
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
