//  OEmbedFetcher.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Fetches OEmbed HTML fragments on behalf of a web view.
final class OEmbedFetcher {
    /// Shared by every fetcher, so a post embedded on one page is ready when it turns up on the next.
    private static let cache = OEmbedCache()

    private let session: URLSession = URLSession(configuration: .ephemeral)

    func fetch(url: URL, id: String) async -> String {
        do {
            let responseData = try await Self.cache.responseData(for: url, session: session)
            let json = try JSONSerialization.jsonObject(with: responseData)
            let callback = try JSONSerialization.data(withJSONObject: ["body": json])
            return String(data: callback, encoding: .utf8)!
        } catch {
            let callback = try! JSONSerialization.data(withJSONObject: ["error": "\(error)"])
            return String(data: callback, encoding: .utf8)!
        }
    }
}

/**
 Keeps successful OEmbed responses in memory for as long as their `cache_age` allows, and shares one request among concurrent lookups of the same URL (e.g. a Bluesky post and its quotes on the same page).

 OEmbed providers like Bluesky put the cache lifetime in the response body rather than in HTTP headers, so `URLCache` can't help here.
 */
private actor OEmbedCache {
    private enum Entry {
        case inFlight(Task<Data, Error>)
        case cached(Data, expires: Date)
    }

    private var entries: [URL: Entry] = [:]

    /// Used when a response doesn't specify its `cache_age`.
    private static let defaultCacheAge: TimeInterval = 60 * 60
    private static let maximumCacheAge: TimeInterval = 24 * 60 * 60
    private static let maximumEntries = 200

    func responseData(for url: URL, session: URLSession) async throws -> Data {
        switch entries[url] {
        case let .cached(data, expires: expires) where expires > .now:
            return data
        case let .inFlight(task):
            return try await task.value
        case .cached, nil:
            break
        }

        let task = Task { try await Self.download(url, session: session) }
        entries[url] = .inFlight(task)
        do {
            let data = try await task.value
            entries[url] = .cached(data, expires: .now + Self.cacheAge(of: data))
            evictIfNeeded()
            return data
        } catch {
            entries[url] = nil
            throw error
        }
    }

    private static func download(_ url: URL, session: URLSession) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let status = (response as? HTTPURLResponse)?.statusCode, status >= 400 {
            struct Failure: Error {}
            throw Failure()
        }
        // Don't cache anything we can't hand back to the web view.
        _ = try JSONSerialization.jsonObject(with: data)
        return data
    }

    /// The response's `cache_age` (seconds; the OEmbed spec allows a number or a string), clamped to `maximumCacheAge`.
    private static func cacheAge(of data: Data) -> TimeInterval {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let cacheAge: TimeInterval? = switch json?["cache_age"] {
        case let number as NSNumber: number.doubleValue
        case let string as String: TimeInterval(string)
        default: nil
        }
        return min(max(cacheAge ?? defaultCacheAge, 0), maximumCacheAge)
    }

    private func evictIfNeeded() {
        guard entries.count > Self.maximumEntries else { return }

        let now = Date.now
        entries = entries.filter {
            if case let .cached(_, expires: expires) = $0.value { expires > now } else { true }
        }

        // Still too many? Drop whatever would expire soonest.
        let cached = entries.compactMap { url, entry -> (URL, Date)? in
            if case let .cached(_, expires: expires) = entry { (url, expires) } else { nil }
        }
        for (url, _) in cached.sorted(by: { $0.1 < $1.1 }).prefix(max(entries.count - Self.maximumEntries, 0)) {
            entries[url] = nil
        }
    }
}
