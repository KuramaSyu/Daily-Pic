//
//  OsuWallpaperApi.swift
//  Daily Pic
//
//  Created by Paul Zenker on 28.05.25.
//

import Foundation
import os

/// Non-2xx HTTP from osu!. The status code is surfaced in
/// localizedDescription so the popover shows a useful hint.
struct OsuHttpError: LocalizedError {
    let statusCode: Int
    var errorDescription: String? {
        switch statusCode {
        case 401, 403:
            return "osu! API rejected the request (HTTP \(statusCode)) - check API id/secret in Settings"
        case ..<200:
            return "osu! API request failed - check API id/secret in Settings"
        default:
            return "osu! API returned HTTP \(statusCode)"
        }
    }
}

struct OsuTokenResponse: Decodable {
    let access_token: String
    let token_type: String
    let expires_in: Int
}

class OsuWallpaperApi: WallpaperApiProtocol, InfoLogging {
    var osuSettings: OsuSettings
    var accessToken: OsuTokenResponse?
    var json_cache: [String: BingApiResponse] = [:]
    let base_api: String = "https://osu.ppy.sh/api/v2"
    private let logger: Logger = Logger(subsystem: "OsuWallpaperApi", category: "network")
    let gallery_model: any GalleryModelProtocol
    var infoLog: InfoLog?

    init(gallery_model: any GalleryModelProtocol) {
        self.osuSettings = OsuSettings()
        self.gallery_model = gallery_model
    }

    private func log(_ msg: String, category: String = "osu") {
        InfoLogCall.info(msg, category: category)
        logger.debug("\(category): \(msg, privacy: .public)")
    }

    /// downlaods seasonal osu wallpapers via GET from /seasonal-backgrounds
    /// date parameter does not matter. it's only to comply to the interface
    func fetchResponse(of date: Date) async throws -> WallpaperResponse? {
        log("fetchResponse start for date=\(date)")
        let api_response = try await getSeasonalBackgrounds()
        log("fetchResponse ok, \(api_response.backgrounds.count) backgrounds")
        return OsuWallpaperAdapter(api_response, gallery_model: self.gallery_model)
    }

    /// Fetches JSON from osu! seasonal API
    func fetchJSON(from url: URL, headers: [String: String]? = nil) async throws -> OsuSeasonalBackgroundsResponse? {
        log("GET \(url.absoluteString)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let headers = headers ?? [:]
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        log("GET \(url.lastPathComponent) -> HTTP \(status), \(data.count) bytes")

        // Reject before decoding so a 4xx error body does not surface
        // as a confusing "decode failed" in the popover.
        guard (200..<300).contains(status) else {
            log("non-2xx HTTP \(status) for \(url.lastPathComponent) - skipping decode")
            throw OsuHttpError(statusCode: status)
        }

        do {
            return try JSONDecoder().decode(OsuSeasonalBackgroundsResponse.self, from: data)
        } catch {
            log("decode failed: \(error.localizedDescription)")
            throw error
        }
    }

    private func getAccessToken() async throws -> OsuTokenResponse {
        if let token = self.accessToken {
            return token
        }
        _ = try await fetchAccessToken()
        return self.accessToken!
    }

    private func getSeasonalBackgrounds() async throws -> OsuSeasonalBackgroundsResponse {
        let endpoint = "/seasonal-backgrounds"
        let token = try await getAccessToken()
        let headers = [
            "Authorization": "Bearer \(token.access_token)",
            "Accept": "application/json"
        ]
        let url = URL(string: base_api + endpoint)!
        guard let response = try await fetchJSON(from: url, headers: headers) else {
            log("seasonal-backgrounds response was nil")
            throw OsuHttpError(statusCode: 0)
        }
        return response
    }

    private func fetchAccessToken() async throws -> String {
        let url = URL(string: "https://osu.ppy.sh/oauth/token")
        guard !osuSettings.osuApiId.isEmpty, !osuSettings.osuApiSecret.isEmpty else {
            log("missing osu! API credentials - set id/secret in Settings")
            throw OsuHttpError(statusCode: 0)
        }
        log("token POST start")

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
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            log("token POST failed HTTP=\(code)")
            throw OsuHttpError(statusCode: code)
        }

        let decoded = try JSONDecoder().decode(OsuTokenResponse.self, from: data)
        log("token POST ok, expires_in=\(decoded.expires_in)s")
        self.accessToken = decoded
        return decoded.access_token
    }
}
