//  PostsViewExternalStylesheetLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking
import Foundation

final class PostsViewExternalStylesheetLoader: NSObject {
    static let sharedLoader: PostsViewExternalStylesheetLoader = {
        guard let stylesheetURLString = Bundle.main.infoDictionary?[externalStylesheetURLKey] as? String else { fatalError("missing Info.plist key for AwfulPostsViewExternalStylesheetURL") }
        let stylesheetURL = URL(string: stylesheetURLString)!
        
        let caches = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let cacheFolder = caches.appendingPathComponent("ExternalStylesheet", isDirectory: true)
        return PostsViewExternalStylesheetLoader(stylesheetURL: stylesheetURL, cacheFolder: cacheFolder)
    }()
    
    static var didUpdateNotification: String {
        return "AwfulPostsViewExternalStylesheetDidUpdate"
    }
    
    fileprivate(set) var stylesheet: String?
    fileprivate let stylesheetURL: URL
    fileprivate let cacheFolder: URL
    fileprivate let session = AFURLSessionManager(sessionConfiguration: URLSessionConfiguration.ephemeral)
    fileprivate var checkingForUpdate = false
    fileprivate var updateTimer: Timer?
    
    init(stylesheetURL: URL, cacheFolder: URL) {
        self.stylesheetURL = stylesheetURL
        self.cacheFolder = cacheFolder
        super.init()
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: NSNotification.Name.UIApplicationDidEnterBackground, object: nil)
        
        startTimer()
    }
    
    func refreshIfNecessary() {
        guard RefreshMinder.sharedMinder.shouldRefresh(.externalStylesheet) && !checkingForUpdate else { return }
        
        checkingForUpdate = true
        
        let request = NSMutableURLRequest(url: stylesheetURL)
        
        if let
            oldResponse = NSKeyedUnarchiver.unarchiveObject(withFile: cachedResponseURL.path) as? HTTPURLResponse,
            let oldURL = oldResponse.url,
            oldURL.absoluteURL == stylesheetURL.absoluteURL
        {
            request.setCacheHeadersWithResponse(oldResponse)
        }
        
        session?.downloadTask(with: request as URLRequest!, progress: nil, destination: { (targetPath, response) -> URL! in
            self.createCacheFolderIfNecessary()
            return self.cachedStylesheetURL
            
            }, completionHandler: { (response, filePath, error) in
                self.checkingForUpdate = false
                
                if
                    let HTTPResponse = (error as NSError?)?.userInfo[AFNetworkingOperationFailingURLResponseErrorKey] as? HTTPURLResponse,
                    HTTPResponse.statusCode == 304
                {
                    RefreshMinder.sharedMinder.didRefresh(.externalStylesheet)
                    return
                }
                
                if let error = error {
                    print("\(#function) error updating external stylesheet: \(error)")
                    return
                }
                
                if let response = response {
                    NSKeyedArchiver.archiveRootObject(response, toFile: self.cachedResponseURL.path)
                }
                
                self.reloadCachedStylesheet()
                
                RefreshMinder.sharedMinder.didRefresh(.externalStylesheet)
                
                NotificationCenter.default.post(name: Notification.Name(rawValue: PostsViewExternalStylesheetLoader.didUpdateNotification), object: self.stylesheet)
        }).resume()
    }
    
    fileprivate var cachedResponseURL: URL {
        return cacheFolder.appendingPathComponent("style.cachedresponse", isDirectory: false)
    }
    
    fileprivate var cachedStylesheetURL: URL {
        return cacheFolder.appendingPathComponent("style.css", isDirectory: false)
    }
    
    fileprivate func createCacheFolderIfNecessary() {
        do {
            try FileManager.default.createDirectory(at: cacheFolder, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            print("\(#function) error creating external stylesheet cache folder \(cacheFolder): \(error)")
        }
    }
    
    fileprivate func reloadCachedStylesheet() {
        do {
            stylesheet = try String(contentsOf: cachedStylesheetURL)
        } catch let error as NSError {
            print("\(#function) error loading cached stylesheet from \(cachedStylesheetURL): \(error)")
        }
    }
    
    fileprivate func startTimer() {
        let interval = RefreshMinder.sharedMinder.suggestedRefreshDate(.externalStylesheet).timeIntervalSinceNow
        updateTimer = Timer.scheduledTimerWithInterval(interval, handler: { [weak self] timer in
            if self?.updateTimer === timer {
                self?.updateTimer = nil
            }
            self?.refreshIfNecessary()
        })
    }
    
    fileprivate func stopTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    @objc fileprivate func applicationWillEnterForeground(_ notification: Notification) {
        refreshIfNecessary()
        startTimer()
    }
    
    @objc fileprivate func applicationDidEnterBackground(_ notification: Notification) {
        stopTimer()
    }
}

private let externalStylesheetURLKey = "AwfulPostsViewExternalStylesheetURL"
