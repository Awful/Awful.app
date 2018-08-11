//  PostsViewExternalStylesheetLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import PromiseKit

private let Log = Logger.get()

final class PostsViewExternalStylesheetLoader: NSObject {
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
    
    private(set) var stylesheet: String?
    private let stylesheetURL: URL
    private let cacheFolder: URL
    private let session = URLSession(configuration: .ephemeral)
    private var checkingForUpdate = false
    private var updateTimer: Timer?
    
    private init(stylesheetURL: URL, cacheFolder: URL) {
        self.stylesheetURL = stylesheetURL
        self.cacheFolder = cacheFolder
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
        
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
        
        if
            let oldResponse = NSKeyedUnarchiver.unarchiveObject(withFile: cachedResponseURL.path) as? HTTPURLResponse,
            let oldURL = oldResponse.url,
            oldURL.absoluteURL == stylesheetURL.absoluteURL
        {
            request.setCacheHeadersWithResponse(oldResponse)
        }

        createCacheFolderIfNecessary()

        session.downloadTask(.promise, with: request, to: cachedStylesheetURL, replacingIfNecessary: true)
            .done { saveLocation, response in
                if let httpResponse = response as? HTTPURLResponse {
                    switch httpResponse.statusCode {
                    case 304:
                        Log.d("stylesheet has not changed")

                        return RefreshMinder.sharedMinder.didRefresh(.externalStylesheet)

                    case 200..<300:
                        Log.d("downloaded new stylesheet")

                    case let code:
                        throw PMKHTTPError.badStatusCode(code, Data(), httpResponse)
                    }
                }

                NSKeyedArchiver.archiveRootObject(response, toFile: self.cachedResponseURL.path)

                self.reloadCachedStylesheet()

                RefreshMinder.sharedMinder.didRefresh(.externalStylesheet)

                NotificationCenter.default.post(
                    name: DidUpdateNotification.name,
                    object: self,
                    userInfo: [DidUpdateNotification.stylesheetKey: self.stylesheet ?? ""])
            }
            .catch { Log.e("could not update external stylesheet: \($0)") }
    }
    
    private var cachedResponseURL: URL {
        return cacheFolder.appendingPathComponent("style.cachedresponse", isDirectory: false)
    }
    
    private var cachedStylesheetURL: URL {
        return cacheFolder.appendingPathComponent("style.css", isDirectory: false)
    }
    
    private func createCacheFolderIfNecessary() {
        do {
            try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            print("\(#function) error creating external stylesheet cache folder \(cacheFolder): \(error)")
        }
    }
    
    private func reloadCachedStylesheet() {
        do {
            stylesheet = try String(contentsOf: cachedStylesheetURL)
        } catch let error as NSError {
            print("\(#function) error loading cached stylesheet from \(cachedStylesheetURL): \(error)")
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
    
    @objc private func applicationWillEnterForeground(_ notification: Notification) {
        refreshIfNecessary()
        startTimer()
    }
    
    @objc private func applicationDidEnterBackground(_ notification: Notification) {
        stopTimer()
    }
}

private let externalStylesheetURLKey = "AwfulPostsViewExternalStylesheetURL"
