//  SmileyUpdater.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Foundation

public class SmileyUpdater: NSObject {
    public let managedObjectContext: NSManagedObjectContext
    private let downloader: SmileyDownloader

    public init(managedObjectContext context: NSManagedObjectContext, downloader: SmileyDownloader) {
        managedObjectContext = context
        self.downloader = downloader
    }
    
    public var automaticallyFetchNewSmileyImageData: Bool = false {
        willSet(doIt) {
            if doIt {
                observer = NewSmileyObserver(managedObjectContext) { [unowned self] keysToURLs in
                    self.downloadImageDataForSmileys(keysToURLs)
                }
            } else {
                observer = nil
            }
        }
    }
    private var observer: NewSmileyObserver?
    
    public convenience init(managedObjectContext context: NSManagedObjectContext) {
        self.init(managedObjectContext: context, downloader: URLSessionSmileyDownloader())
    }
    
    public func downloadMissingImageData() {
        let request = NSFetchRequest(entityName: "Smiley")
        request.predicate = NSPredicate(format: "imageData = nil AND imageURL != nil")
        managedObjectContext.performBlock {
            var error: NSError?
            if let results = self.managedObjectContext.executeFetchRequest(request, error: &error) {
                let keysToURLs = reduce(results as [Smiley], [SmileyPrimaryKey:NSURL](), insertKeyAndImageURL)
                self.downloadImageDataForSmileys(keysToURLs)
            } else {
                NSLog("[%@ %@] error fetching smileys missing image data: %@", self, __FUNCTION__, error!)
            }
        }
    }
    
    private func downloadImageDataForSmileys(keysToURLs: [SmileyPrimaryKey:NSURL]) {
        for (text, URL) in keysToURLs {
            self.downloader.downloadImageDataFromURL(URL) { [unowned self] imageData, error in
                if let error = error {
                    NSLog("[%@ %@] error downloading image for smiley %@: %@", self, __FUNCTION__, text, error)
                } else {
                    self.managedObjectContext.performBlock {
                        if let smiley = Smiley.smileyWithText(text, inContext: self.managedObjectContext) {
                            smiley.imageData = imageData
                            var error: NSError?
                            if !self.managedObjectContext.save(&error) {
                                NSLog("[%@ %@] error saving context: %@", self, __FUNCTION__, error!)
                            }
                        } else {
                            NSLog("[%@ %@] could not find smiley %@", self, __FUNCTION__, text)
                        }
                    }
                }
            }
        }
    }
}


public protocol SmileyDownloader {
    func downloadImageDataFromURL(URL: NSURL, completionBlock: (imageData: NSData!, error: NSError!) -> Void)
}

private class URLSessionSmileyDownloader: SmileyDownloader {
    lazy var session: NSURLSession = {
        let configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration()
        configuration.networkServiceType = .NetworkServiceTypeBackground
        return NSURLSession(configuration: configuration)
    }()
    
    func downloadImageDataFromURL(URL: NSURL, completionBlock: (imageData: NSData!, error: NSError!) -> Void) {
        let task = session.dataTaskWithURL(URL) { imageData, response, error in
            if let response = response as? NSHTTPURLResponse {
                if 200..<299 ~= (response as NSHTTPURLResponse).statusCode {
                    dispatch_async(dispatch_get_main_queue()) {
                        completionBlock(imageData: imageData, error: nil)
                    }
                } else {
                    let error = NSError(domain: "SmileyErrorDomain", code: 1, userInfo: ["HTTPResponseKey": response])
                    dispatch_async(dispatch_get_main_queue()) {
                        completionBlock(imageData: nil, error: error)
                    }
                }
            } else {
                let error = NSError(domain: "SmileyErrorDomain", code: 1, userInfo: [NSUnderlyingErrorKey: error])
                dispatch_async(dispatch_get_main_queue()) {
                    completionBlock(imageData: nil, error: error)
                }
            }
        }
        task.resume()
    }
}

private class NewSmileyObserver {
    let managedObjectContext: NSManagedObjectContext
    let notificationBlock: ([SmileyPrimaryKey:NSURL]) -> Void
    private let observer: AnyObject
    
    init(_ context: NSManagedObjectContext, notificationBlock block: ([SmileyPrimaryKey:NSURL]) -> Void) {
        managedObjectContext = context
        notificationBlock = block
        observer = NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: context, queue: nil) { notification in
            let userInfo = notification.userInfo as [String:NSSet]
            let smileys = filter(userInfo[NSInsertedObjectsKey]!) { $0 is Smiley } as [Smiley]
            let needingImageData = filter(smileys) { $0.imageData == nil && $0.imageURL != nil }
            let keysToURLs = reduce(needingImageData, [SmileyPrimaryKey:NSURL](), insertKeyAndImageURL)
            if keysToURLs.isEmpty { return }
            dispatch_async(dispatch_get_main_queue()) {
                block(keysToURLs)
            }
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(observer)
    }
}

private func insertKeyAndImageURL(var keysToURLs: [SmileyPrimaryKey:NSURL], smiley: Smiley) -> [SmileyPrimaryKey:NSURL] {
    if let URL = NSURL.URLWithString(smiley.imageURL!) {
        keysToURLs[smiley.text] = URL
    }
    return keysToURLs
}
