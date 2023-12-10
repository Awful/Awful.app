//  PostsViewExternalStylesheetLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Combine
import Foundation

private let Log = Logger.get()

@MainActor final class PostsViewExternalStylesheetLoader {

    static let shared: PostsViewExternalStylesheetLoader = {
        guard let stylesheetURLString = Bundle.main.infoDictionary?[externalStylesheetURLKey] as? String else {
            fatalError("missing Info.plist key for AwfulPostsViewExternalStylesheetURL")
        }
        let stylesheetURL = URL(string: stylesheetURLString)!
        
        let caches = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let cacheFolder = caches.appendingPathComponent("ExternalStylesheet", isDirectory: true)
        return PostsViewExternalStylesheetLoader(stylesheetURL: stylesheetURL, cacheFolder: cacheFolder)
    }()

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
    private var cancellables: Set<AnyCancellable> = []
    private let session = URLSession(configuration: .ephemeral)
    private var checkingForUpdate = false
    private var updateTimer: Timer?
    
    private init(stylesheetURL: URL, cacheFolder: URL) {
        self.stylesheetURL = stylesheetURL
        self.cacheFolder = cacheFolder
        
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
    
    func refreshIfNecessary() {
        guard !checkingForUpdate else { return }

        guard RefreshMinder.sharedMinder.shouldRefresh(.externalStylesheet) else {
            Log.d("not going to check for updated stylesheet yet")
            return
        }
        
        checkingForUpdate = true
        Log.d("checking for updated stylesheet")
        
        var request = URLRequest(url: stylesheetURL)

        var oldResponse: HTTPURLResponse? {
            guard let data = try? Data(contentsOf: cachedResponseURL) else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HTTPURLResponse.self, from: data)
        }
        
        if let oldResponse = oldResponse,
           let oldURL = oldResponse.url,
           oldURL.absoluteURL == stylesheetURL.absoluteURL
        {
            request.setCacheHeadersWithResponse(oldResponse)
        }

        createCacheFolderIfNecessary()

        Task { [request] in
            do {
                let (tempURL, response) = try await session.download(for: request)
                switch (response as! HTTPURLResponse).statusCode {
                case 200..<300:
                    let fileManager = FileManager.default
                    do {
                        try fileManager.moveItem(at: tempURL, to: cachedStylesheetURL)
                    } catch CocoaError.fileWriteFileExists {
                        _ = try fileManager.replaceItemAt(cachedStylesheetURL, withItemAt: tempURL, options: .usingNewMetadataOnly)
                    }
                    Log.d("downloaded new stylesheet")

                case 304:
                    Log.d("stylesheet has not changed")
                    RefreshMinder.sharedMinder.didRefresh(.externalStylesheet)
                    return

                case let statusCode:
                    throw StylesheetLoaderError.badStatusCode(statusCode, response.url)
                }

                do {
                    let data = try NSKeyedArchiver.archivedData(withRootObject: response, requiringSecureCoding: false)
                    try data.write(to: cachedResponseURL)
                } catch {
                    Log.e("could not write cached stylesheet to \(cachedResponseURL): \(error)")
                }

                reloadCachedStylesheet()

                RefreshMinder.sharedMinder.didRefresh(.externalStylesheet)

                NotificationCenter.default.post(
                    name: DidUpdateNotification.name,
                    object: self,
                    userInfo: [DidUpdateNotification.stylesheetKey: stylesheet ?? ""]
                )
            } catch {
                Log.e("could not update external stylesheet: \(error)")
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
            Log.e("error creating external stylesheet cache folder \(cacheFolder): \(error)")
        }
    }
    
    private func reloadCachedStylesheet() {
        do {
            stylesheet = try String(contentsOf: cachedStylesheetURL)
        } catch {
            Log.e("error loading cached stylesheet from \(cachedStylesheetURL): \(error)")
        }
    }
    
    private func startTimer() {
        let interval = RefreshMinder.sharedMinder.suggestedRefreshDate(.externalStylesheet).timeIntervalSinceNow
        updateTimer = Timer.scheduledTimerWithInterval(interval, handler: { [weak self] timer in
            if self?.updateTimer === timer {
                self?.updateTimer = nil
            }
            self?.refreshIfNecessary()
        })
    }
    
    private func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
}

private let externalStylesheetURLKey = "AwfulPostsViewExternalStylesheetURL"
