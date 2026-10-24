//
//  NetworkSession.swift
//  Daily Pic
//
//  Created by Paul Zenker on 21.10.26.
//

import Foundation

/// Single source for HTTP sessions in the app.
///
/// Every session is ephemeral with no URL cache, no HTTP cookies, and
/// `requestCachePolicy = .reloadIgnoringLocalCacheData`. That keeps the
/// sandbox container's `Library/Caches/` and `Library/HTTPStorages/`
/// directories empty, so the `com.apple.cache_delete` (runningboardd)
/// scan has nothing to reclaim and won't SIGKILL the app to free space.
enum NetworkSession {
    /// Build a fresh ephemeral session. Per-call so no shared mutable
    /// state lives inside URLSession across requests.
    static func makeEphemeral(
        timeoutIntervalForRequest: TimeInterval = 30,
        timeoutIntervalForResource: TimeInterval = 300
    ) -> URLSession {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = true
        cfg.timeoutIntervalForRequest = timeoutIntervalForRequest
        cfg.timeoutIntervalForResource = timeoutIntervalForResource
        cfg.allowsConstrainedNetworkAccess = true
        cfg.allowsExpensiveNetworkAccess = true
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.urlCache = nil
        cfg.httpCookieStorage = nil
        cfg.httpShouldSetCookies = false
        cfg.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: cfg)
    }

    /// Async data(for:) helper that always uses an ephemeral session.
    static func data(for request: URLRequest, timeoutForResource: TimeInterval = 300) async throws -> (Data, URLResponse) {
        var req = request
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let session = makeEphemeral(timeoutIntervalForResource: timeoutForResource)
        defer { session.invalidateAndCancel() }
        return try await session.data(for: req)
    }

    /// Async download(from:) helper that always uses an ephemeral session.
    static func download(from url: URL, timeoutForResource: TimeInterval = 300) async throws -> (URL, URLResponse) {
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let session = makeEphemeral(timeoutIntervalForResource: timeoutForResource)
        defer { session.invalidateAndCancel() }
        return try await session.download(for: req)
    }
}
