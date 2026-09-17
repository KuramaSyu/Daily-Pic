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
    private var accessTokenExpiresAt: Date?
    var json_cache: [String: BingApiResponse] = [:]
    let base_api: String = "https://osu.ppy.sh/api/v2"
    private let logger: Logger = Logger(subsystem: "OsuWallpaperApi", category: "network")
    let gallery_model: any GalleryModelProtocol
    var infoLog: InfoLog?

    init(gallery_model: any GalleryModelProtocol) {
        self.osuSettings = OsuSettings()
        self.gallery_model = gallery_model
    }

    private func log(_ msg: String, category: String = "osu", kind: InfoLogKind = .info) {
        InfoLogCall.info(msg, category: category, kind: kind)
        switch kind {
        case .error:   logger.error("\(category): \(msg, privacy: .public)")
        case .warning: logger.warning("\(category): \(msg, privacy: .public)")
        default:       logger.debug("\(category): \(msg, privacy: .public)")
        }
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log("GET \(url.lastPathComponent) failed: \(error.localizedDescription)", kind: .error)
            throw error
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        log("GET \(url.lastPathComponent) -> HTTP \(status), \(data.count) bytes")

        // Reject before decoding so a 4xx error body does not surface
        // as a confusing "decode failed" in the popover.
        guard (200..<300).contains(status) else {
            // Drop the cached access token so the next call re-POSTs to /oauth/token.
            // osu! returns 401/403 from /seasonal-backgrounds when the token has
            // been revoked, rotated, or the client lost its scope - keeping the
            // stale token would just produce a 401 storm for the rest of the run.
            if (400..<500).contains(status) {
                self.accessToken = nil
                self.accessTokenExpiresAt = nil
                log("invalidated cached access token (HTTP \(status))", kind: .warning)
            }
            log("non-2xx HTTP \(status) for \(url.lastPathComponent) - skipping decode", kind: .error)
            throw OsuHttpError(statusCode: status)
        }

        do {
            return try JSONDecoder().decode(OsuSeasonalBackgroundsResponse.self, from: data)
        } catch {
            log("decode failed: \(error.localizedDescription)", kind: .error)
            throw error
        }
    }

    private func getAccessToken() async throws -> OsuTokenResponse {
        // Reuse only if we actually have a token AND its expiry is still in
        // the future. expires_in is a 24h budget, so a stale token from
        // yesterday would otherwise get reused for days (menu-bar app stays
        // resident). Refresh early so a clock-edge 401 doesn't reach the user.
        if let token = self.accessToken,
           let expiresAt = self.accessTokenExpiresAt,
           expiresAt > Date() {
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
            log("missing osu! API credentials - set id/secret in Settings", kind: .error)
            throw OsuHttpError(statusCode: 0)
        }
        log("token POST start")

        // headers
        var request = URLRequest(url: url!)
        request.httpMethod = "POST"
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            log("token POST failed: \(error.localizedDescription)", kind: .error)
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            log("token POST failed HTTP=\(code)", kind: .error)
            throw OsuHttpError(statusCode: code)
        }

        let decoded = try JSONDecoder().decode(OsuTokenResponse.self, from: data)
        log("token POST ok, expires_in=\(decoded.expires_in)s")
        self.accessToken = decoded
        // Record the wall-clock expiry so getAccessToken can decide whether
        // to reuse it without round-tripping to osu! first.
        self.accessTokenExpiresAt = Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        return decoded.access_token
    }
}
