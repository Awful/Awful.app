//  SmilieUpdater.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Foundation

public class SmilieUpdater: NSObject {
    public let managedObjectContext: NSManagedObjectContext
    private let downloader: SmilieDownloader

    public init(managedObjectContext context: NSManagedObjectContext, downloader: SmilieDownloader) {
        managedObjectContext = context
        self.downloader = downloader
    }
    
    public var automaticallyFetchNewSmilieImageData: Bool = false {
        willSet(doIt) {
            if doIt {
                observer = NewSmilieObserver(managedObjectContext) { [unowned self] keysToURLs in
                    self.downloadImageDataForSmilies(keysToURLs)
                }
            } else {
                observer = nil
            }
        }
    }
    private var observer: NewSmilieObserver?
    
    public convenience init(managedObjectContext context: NSManagedObjectContext) {
        self.init(managedObjectContext: context, downloader: URLSessionSmilieDownloader())
    }
    
    public func downloadMissingImageData() -> NSProgress {
        let progress = NSProgress(totalUnitCount: -1)
        let request = NSFetchRequest(entityName: "Smilie")
        request.predicate = NSPredicate(format: "imageData = nil AND imageURL != nil")
        managedObjectContext.performBlock {
            var error: NSError?
            if let results = self.managedObjectContext.executeFetchRequest(request, error: &error) {
                let keysToURLs = reduce(results as [Smilie], [SmiliePrimaryKey:NSURL](), insertKeyAndImageURL)
                progress.totalUnitCount = Int64(keysToURLs.count)
                progress.becomeCurrentWithPendingUnitCount(Int64(keysToURLs.count))
                self.downloadImageDataForSmilies(keysToURLs)
                progress.resignCurrent()
            } else {
                NSLog("[%@ %@] error fetching smilies missing image data: %@", self, __FUNCTION__, error!)
            }
        }
        return progress
    }
    
    private func downloadImageDataForSmilies(keysToURLs: [SmiliePrimaryKey:NSURL]) {
        for (text, URL) in keysToURLs {
            let progress = NSProgress(totalUnitCount: 1)
            self.downloader.downloadImageDataFromURL(URL) { [unowned self] imageData, error in
                if let error = error {
                    NSLog("[%@ %@] error downloading image for smilie %@: %@", self, __FUNCTION__, text, error)
                } else {
                    self.managedObjectContext.performBlock {
                        if let smilie = Smilie.smilieWithText(text, inContext: self.managedObjectContext) {
                            smilie.imageData = imageData
                            var error: NSError?
                            if self.managedObjectContext.save(&error) {
                                progress.completedUnitCount = 1
                            } else {
                                NSLog("[%@ %@] error saving context: %@", self, __FUNCTION__, error!)
                            }
                        } else {
                            NSLog("[%@ %@] could not find smilie %@", self, __FUNCTION__, text)
                        }
                    }
                }
            }
        }
    }
}

private class NewSmilieObserver {
    let managedObjectContext: NSManagedObjectContext
    let notificationBlock: ([SmiliePrimaryKey:NSURL]) -> Void
    private let observer: AnyObject
    
    init(_ context: NSManagedObjectContext, notificationBlock block: ([SmiliePrimaryKey:NSURL]) -> Void) {
        managedObjectContext = context
        notificationBlock = block
        observer = NSNotificationCenter.defaultCenter().addObserverForName(NSManagedObjectContextDidSaveNotification, object: context, queue: nil) { notification in
            let userInfo = notification.userInfo as [String:NSSet]
            let smilies = filter(userInfo[NSInsertedObjectsKey]!) { $0 is Smilie } as [Smilie]
            let needingImageData = filter(smilies) { $0.imageData == nil && $0.imageURL != nil }
            let keysToURLs = reduce(needingImageData, [SmiliePrimaryKey:NSURL](), insertKeyAndImageURL)
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

private func insertKeyAndImageURL(var keysToURLs: [SmiliePrimaryKey:NSURL], smilie: Smilie) -> [SmiliePrimaryKey:NSURL] {
    if let URL = NSURL.URLWithString(smilie.imageURL!) {
        keysToURLs[smilie.text] = URL
    }
    return keysToURLs
}
