//  PostsViewExternalStylesheetLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Combine
import os
import UIKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "PostsViewExternalStylesheetLoader")

@MainActor final class PostsViewExternalStylesheetLoader {

    static let shared: PostsViewExternalStylesheetLoader = {
        guard let stylesheetURLString = Bundle.main.infoDictionary?[externalStylesheetURLKey] as? String else {
            fatalError("missing Info.plist key for AwfulPostsViewExternalStylesheetURL")
        }
        let stylesheetURL = URL(string: stylesheetURLString)!
        
        let cacheFolder = cachesFolder.appendingPathComponent("ExternalStylesheet", isDirectory: true)
        return PostsViewExternalStylesheetLoader(stylesheetURL: stylesheetURL, cacheFolder: cacheFolder, refresh: .externalStylesheet)
    }()

    /// Custom platinum icons (the feather, the pumpkin, etc.), made from the Forums' own `platicons.css` so new icons show up without an app update.
    static let platinumIcons: PostsViewExternalStylesheetLoader = {
        let cacheFolder = cachesFolder.appendingPathComponent("PlatinumIcons", isDirectory: true)
        let builder = PlatinumIconStylesheetBuilder(cacheFolder: cacheFolder)
        return PostsViewExternalStylesheetLoader(
            stylesheetURL: PlatinumIcons.siteStylesheetURL,
            cacheFolder: cacheFolder,
            refresh: .platinumIcons,
            transform: { await builder.postsViewStylesheet(fromSiteStylesheet: $0) }
        )
    }()

    private static var cachesFolder: URL {
        try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    /// Turns the downloaded stylesheet into what gets put in the posts view. When `isComplete` is `false`, the result is used but the download will be tried again at the next opportunity.
    typealias Transform = @MainActor (_ downloaded: String) async -> (stylesheet: String, isComplete: Bool)

    struct DidUpdateNotification {
        let stylesheet: String

        static let name = Notification.Name("AwfulPostsViewExternalStylesheetDidUpdate")
        static let stylesheetKey = "stylesheet"

        init?(_ notification: Notification) {
            guard notification.name == DidUpdateNotification.name else { return nil }
            stylesheet = notification.userInfo![DidUpdateNotification.stylesheetKey] as! String
        }
    }

    enum StylesheetLoaderError: LocalizedError {
        case badStatusCode(Int, URL?)

        var errorDescription: String? {
            switch self {
            case let .badStatusCode(statusCode, url):
                return "Invalid HTTP response (\(statusCode) for \(url?.absoluteString ?? "nil")"
            }
        }
    }

    private(set) var stylesheet: String?
    private let stylesheetURL: URL
    private let cacheFolder: URL
    private let refresh: RefreshMinder.Refresh
    private let transform: Transform?
    private var cancellables: Set<AnyCancellable> = []
    private let session = URLSession(configuration: .ephemeral)
    private var checkingForUpdate = false
    private var updateTimer: Task<Void, Never>?

    private init(stylesheetURL: URL, cacheFolder: URL, refresh: RefreshMinder.Refresh, transform: Transform? = nil) {
        self.stylesheetURL = stylesheetURL
        self.cacheFolder = cacheFolder
        self.refresh = refresh
        self.transform = transform

        if FileManager.default.fileExists(atPath: cachedStylesheetURL.path) {
            reloadCachedStylesheet()
        }
        
        let app = UIApplication.shared
        let noteCenter = NotificationCenter.default
        Task { [weak self] in
            for await _ in noteCenter.notifications(named: UIApplication.willEnterForegroundNotification, object: app).map({ _ in }) {
                guard let self else { return }
                refreshIfNecessary()
                startTimer()
            }
        }.store(in: &cancellables)
        Task { [weak self] in
            for await _ in noteCenter.notifications(named: UIApplication.didEnterBackgroundNotification, object: app).map({ _ in }) {
                self?.stopTimer()
            }
        }.store(in: &cancellables)

        startTimer()
    }

    deinit {
        updateTimer?.cancel()
    }

    func refreshIfNecessary() {
        guard !checkingForUpdate else { return }

        // The system can empty the caches folder whenever it likes, so don't wait out the refresh interval with nothing to show.
        guard RefreshMinder.sharedMinder.shouldRefresh(refresh) || stylesheet == nil else {
            logger.debug("not going to check for updated stylesheet yet")
            return
        }
        
        checkingForUpdate = true
        logger.debug("checking for updated stylesheet")
        
        var request = URLRequest(url: stylesheetURL)

        var oldResponse: HTTPURLResponse? {
            guard let data = try? Data(contentsOf: cachedResponseURL) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HTTPURLResponse.self, from: data)
        }
        
        if stylesheet != nil,
           let oldResponse = oldResponse,
           let oldURL = oldResponse.url,
           oldURL.absoluteURL == stylesheetURL.absoluteURL
        {
            request.setCacheHeaders(oldResponse)
        }

        createCacheFolderIfNecessary()

        Task { [request] in
            defer { checkingForUpdate = false }
            do {
                let (tempURL, response) = try await session.download(for: request)
                var isComplete = true
                switch (response as! HTTPURLResponse).statusCode {
                case 200..<300:
                    if let transform {
                        let downloaded = try String(contentsOf: tempURL, encoding: .utf8)
                        let transformed = await transform(downloaded)
                        try transformed.stylesheet.write(to: cachedStylesheetURL, atomically: true, encoding: .utf8)
                        isComplete = transformed.isComplete
                    } else {
                        let fileManager = FileManager.default
                        do {
                            try fileManager.moveItem(at: tempURL, to: cachedStylesheetURL)
                        } catch CocoaError.fileWriteFileExists {
                            _ = try fileManager.replaceItemAt(cachedStylesheetURL, withItemAt: tempURL, options: .usingNewMetadataOnly)
                        }
                    }
                    logger.debug("downloaded new stylesheet from \(self.stylesheetURL)")

                case 304:
                    logger.debug("stylesheet has not changed")
                    RefreshMinder.sharedMinder.didRefresh(refresh)
                    return

                case let statusCode:
                    throw StylesheetLoaderError.badStatusCode(statusCode, response.url)
                }

                reloadCachedStylesheet()

                if isComplete {
                    do {
                        let data = try NSKeyedArchiver.archivedData(withRootObject: response, requiringSecureCoding: false)
                        try data.write(to: cachedResponseURL)
                    } catch {
                        logger.error("could not write cached stylesheet to \(self.cachedResponseURL): \(error)")
                    }

                    RefreshMinder.sharedMinder.didRefresh(refresh)
                } else {
                    // Forget the old response so the next check downloads the whole thing again, rather than getting told it's unchanged.
                    try? FileManager.default.removeItem(at: cachedResponseURL)
                    logger.debug("stylesheet from \(self.stylesheetURL) is incomplete, will try again later")
                }

                NotificationCenter.default.post(
                    name: DidUpdateNotification.name,
                    object: self,
                    userInfo: [DidUpdateNotification.stylesheetKey: stylesheet ?? ""]
                )
            } catch {
                logger.error("could not update external stylesheet: \(error)")
            }
        }
    }
    
    private var cachedResponseURL: URL {
        cacheFolder.appendingPathComponent("style.cachedresponse", isDirectory: false)
    }
    
    private var cachedStylesheetURL: URL {
        cacheFolder.appendingPathComponent("style.css", isDirectory: false)
    }
    
    private func createCacheFolderIfNecessary() {
        do {
            try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true, attributes: nil)
        } catch {
            logger.error("error creating external stylesheet cache folder \(self.cacheFolder): \(error)")
        }
    }
    
    func clearCache() {
        let fileManager = FileManager.default
        if let contents = try? fileManager.contentsOfDirectory(at: cacheFolder, includingPropertiesForKeys: nil) {
            for url in contents {
                try? fileManager.removeItem(at: url)
            }
        }
        stylesheet = nil
        RefreshMinder.sharedMinder.forget(refresh)
    }

    private func reloadCachedStylesheet() {
        do {
            stylesheet = try String(contentsOf: cachedStylesheetURL)
        } catch {
            logger.error("error loading cached stylesheet from \(self.cachedStylesheetURL): \(error)")
        }
    }
    
    private func startTimer() {
        let interval = RefreshMinder.sharedMinder.suggestedRefreshDate(refresh).timeIntervalSinceNow
        updateTimer = Task { [weak self] in
            do {
                if interval > 0 {
                    try await Task.sleep(timeInterval: interval)
                }
                self?.refreshIfNecessary()
            } catch {}
        }
    }
    
    private func stopTimer() {
        updateTimer?.cancel()
        updateTimer = nil
    }
}

private let externalStylesheetURLKey = "AwfulPostsViewExternalStylesheetURL"
