//  PostsViewExternalStylesheetLoader.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AFNetworking
import Foundation

final class PostsViewExternalStylesheetLoader: NSObject {
    static let sharedLoader: PostsViewExternalStylesheetLoader = {
        guard let stylesheetURLString = NSBundle.mainBundle().infoDictionary?[externalStylesheetURLKey] as? String else { fatalError("missing Info.plist key for AwfulPostsViewExternalStylesheetURL") }
        let stylesheetURL = NSURL(string: stylesheetURLString)!
        
        let caches = try! NSFileManager.defaultManager().URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        let cacheFolder = caches.URLByAppendingPathComponent("ExternalStylesheet", isDirectory: true)
        return PostsViewExternalStylesheetLoader(stylesheetURL: stylesheetURL, cacheFolder: cacheFolder)
    }()
    
    static var didUpdateNotification: String {
        return "AwfulPostsViewExternalStylesheetDidUpdate"
    }
    
    private(set) var stylesheet: String?
    private let stylesheetURL: NSURL
    private let cacheFolder: NSURL
    private let session = AFURLSessionManager(sessionConfiguration: NSURLSessionConfiguration.ephemeralSessionConfiguration())
    private var checkingForUpdate = false
    private var updateTimer: NSTimer?
    
    init(stylesheetURL: NSURL, cacheFolder: NSURL) {
        self.stylesheetURL = stylesheetURL
        self.cacheFolder = cacheFolder
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplicationWillEnterForegroundNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplicationDidEnterBackgroundNotification, object: nil)
        
        startTimer()
    }
    
    func refreshIfNecessary() {
        guard RefreshMinder.sharedMinder.shouldRefresh(.ExternalStylesheet) && !checkingForUpdate else { return }
        
        checkingForUpdate = true
        
        let request = NSMutableURLRequest(URL: stylesheetURL)
        
        if let
            oldResponse = NSKeyedUnarchiver.unarchiveObjectWithFile(cachedResponseURL.path!) as? NSHTTPURLResponse,
            let oldURL = oldResponse.URL,
            oldURL.absoluteURL == stylesheetURL.absoluteURL
        {
            request.setCacheHeadersWithResponse(oldResponse)
        }
        
        session.downloadTaskWithRequest(request, progress: nil, destination: { (targetPath, response) -> NSURL! in
            self.createCacheFolderIfNecessary()
            return self.cachedStylesheetURL
            
            }, completionHandler: { (response, filePath, error) in
                self.checkingForUpdate = false
                
                if let
                    HTTPResponse = error?.userInfo[AFNetworkingOperationFailingURLResponseErrorKey] as? NSHTTPURLResponse
                    , HTTPResponse.statusCode == 304
                {
                    RefreshMinder.sharedMinder.didRefresh(.ExternalStylesheet)
                    return
                }
                
                if let error = error {
                    print("\(#function) error updating external stylesheet: \(error)")
                    return
                }
                
                NSKeyedArchiver.archiveRootObject(response, toFile: self.cachedResponseURL.path!)
                
                self.reloadCachedStylesheet()
                
                RefreshMinder.sharedMinder.didRefresh(.ExternalStylesheet)
                
                NSNotificationCenter.defaultCenter().postNotificationName(PostsViewExternalStylesheetLoader.didUpdateNotification, object: self.stylesheet)
        }).resume()
    }
    
    private var cachedResponseURL: NSURL {
        return cacheFolder.URLByAppendingPathComponent("style.cachedresponse", isDirectory: false)
    }
    
    private var cachedStylesheetURL: NSURL {
        return cacheFolder.URLByAppendingPathComponent("style.css", isDirectory: false)
    }
    
    private func createCacheFolderIfNecessary() {
        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(cacheFolder, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            print("\(#function) error creating external stylesheet cache folder \(cacheFolder): \(error)")
        }
    }
    
    private func reloadCachedStylesheet() {
        do {
            stylesheet = try String(contentsOfURL: cachedStylesheetURL)
        } catch let error as NSError {
            print("\(#function) error loading cached stylesheet from \(cachedStylesheetURL): \(error)")
        }
    }
    
    private func startTimer() {
        let interval = RefreshMinder.sharedMinder.suggestedRefreshDate(.ExternalStylesheet).timeIntervalSinceNow
        updateTimer = NSTimer.scheduledTimerWithInterval(interval, handler: { [weak self] timer in
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
    
    @objc private func applicationWillEnterForeground(notification: NSNotification) {
        refreshIfNecessary()
        startTimer()
    }
    
    @objc private func applicationDidEnterBackground(notification: NSNotification) {
        stopTimer()
    }
}

private let externalStylesheetURLKey = "AwfulPostsViewExternalStylesheetURL"
