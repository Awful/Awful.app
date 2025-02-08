//  OEmbedFetcher.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/// Fetches OEmbed HTML fragments on behalf of a web view.
final class OEmbedFetcher {
    private let session: URLSession = URLSession(configuration: .ephemeral)

    func fetch(url: URL, id: String) async -> String {
        do {
            let (responseData, urlResponse) = try await session.data(from: url)
            if let status = (urlResponse as? HTTPURLResponse)?.statusCode, status >= 400 {
                struct Failure: Error {}
                throw Failure()
            }
            let json = try JSONSerialization.jsonObject(with: responseData)
            let callback = try JSONSerialization.data(withJSONObject: ["body": json])
            return String(data: callback, encoding: .utf8)!
        } catch {
            let callback = try! JSONSerialization.data(withJSONObject: ["error": "\(error)"])
            return String(data: callback, encoding: .utf8)!
        }
    }
}
