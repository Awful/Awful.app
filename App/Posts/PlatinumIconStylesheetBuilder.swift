//  PlatinumIconStylesheetBuilder.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation
import os

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PlatinumIconStylesheetBuilder")

/// Turns the Forums' `platicons.css` into a posts view stylesheet, figuring out along the way which icons are black and so should get the same per-theme treatment as the platinum grenade.
///
/// Whether an icon is black is remembered by image URL, so each icon only gets downloaded and checked once.
@MainActor final class PlatinumIconStylesheetBuilder {
    private let blackIconsCacheURL: URL
    private let session = URLSession(configuration: .ephemeral)

    init(cacheFolder: URL) {
        blackIconsCacheURL = cacheFolder.appendingPathComponent("blackIcons.json", isDirectory: false)
    }

    /// `isComplete` is `false` when some icons couldn't be downloaded, so they should be tried again later. Those icons still show up, they just won't get any per-theme treatment.
    func postsViewStylesheet(fromSiteStylesheet css: String) async -> (stylesheet: String, isComplete: Bool) {
        let icons = PlatinumIcons.parse(siteStylesheet: css)
        var isBlack = loadCache()

        let unknownURLs = Set(icons.map(\.imageURL.absoluteString)).subtracting(isBlack.keys).compactMap(URL.init(string:))
        var isComplete = true
        if !unknownURLs.isEmpty {
            logger.debug("checking \(unknownURLs.count) platinum icons for black")
            let (checked, failed) = await check(unknownURLs)
            isBlack.merge(checked, uniquingKeysWith: { $1 })
            isComplete = failed.isEmpty
            saveCache(isBlack)
        }

        let stylesheet = PlatinumIcons.postsViewStylesheet(for: icons, isBlack: { isBlack[$0.absoluteString] ?? false })
        return (stylesheet, isComplete)
    }

    /// `failed` are the icons worth trying again later. Icons that aren't there (e.g. a 404) count as checked and not black.
    private func check(_ urls: [URL]) async -> (checked: [String: Bool], failed: [URL]) {
        var checked: [String: Bool] = [:]
        var failed: [URL] = []
        let batchSize = 4
        for batchStart in stride(from: 0, to: urls.count, by: batchSize) {
            let batch = urls[batchStart ..< min(batchStart + batchSize, urls.count)]
            await withTaskGroup(of: (URL, Result<Bool, Error>).self) { group in
                for url in batch {
                    group.addTask { [session] in
                        do {
                            let (data, response) = try await session.data(from: url)
                            switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
                            case 200..<300:
                                return (url, .success(PlatinumIcons.isBlack(imageData: data)))
                            case 400..<500:
                                return (url, .success(false))
                            default:
                                return (url, .failure(URLError(.badServerResponse)))
                            }
                        } catch {
                            return (url, .failure(error))
                        }
                    }
                }
                for await (url, result) in group {
                    switch result {
                    case .success(let isBlack):
                        checked[url.absoluteString] = isBlack
                    case .failure(let error):
                        logger.debug("could not download platinum icon \(url): \(error)")
                        failed.append(url)
                    }
                }
            }
        }
        return (checked, failed)
    }

    private func loadCache() -> [String: Bool] {
        guard let data = try? Data(contentsOf: blackIconsCacheURL) else { return [:] }
        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    private func saveCache(_ isBlack: [String: Bool]) {
        do {
            try JSONEncoder().encode(isBlack).write(to: blackIconsCacheURL, options: .atomic)
        } catch {
            logger.error("could not save black platinum icons to \(self.blackIconsCacheURL): \(error)")
        }
    }
}
