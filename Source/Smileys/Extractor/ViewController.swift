//  ViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import UIKit

class ViewController: UIViewController {
    
    @IBOutlet private weak var replaceBarButtonItem: UIBarButtonItem!
    private var pathTextView: UITextView { get { return view as UITextView } }
    
    private lazy var storeURL: NSURL = {
        let appSupportURL = NSFileManager.defaultManager().URLsForDirectory(.ApplicationSupportDirectory, inDomains: .UserDomainMask).last! as NSURL
        var error: NSError?
        let ok = NSFileManager.defaultManager().createDirectoryAtURL(appSupportURL, withIntermediateDirectories: true, attributes: nil, error: &error)
        assert(ok, "error creating app support folder: \(error)")
        return appSupportURL.URLByAppendingPathComponent("Smileys.sqlite")
        }()
    
    private lazy var storeCoordinator: NSPersistentStoreCoordinator = {
        let modelURL = NSBundle.mainBundle().URLForResource("Smileys", withExtension: "momd")
        let model = NSManagedObjectModel(contentsOfURL: modelURL!)
        return NSPersistentStoreCoordinator(managedObjectModel: model)
        }()
    
    private var context: NSManagedObjectContext!
    private var progress: NSProgress?
    private var updater: SmileyUpdater!

    @IBAction func extractAndSave(sender: UIBarButtonItem) {
        sender.enabled = false
        NSFileManager.defaultManager().removeItemAtURL(storeURL, error: nil)
        let options = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
        var error: NSError?
        let store = storeCoordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: "NoMetadata", URL: storeURL, options: options, error: &error)
        assert(store != nil, "error adding store at \(storeURL): \(error)")
        context = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        context.persistentStoreCoordinator = storeCoordinator
        
        let archiveURL = NSBundle.mainBundle().URLForResource("showsmileys", withExtension: "webarchive")!
        let archive = WebArchive(URL: archiveURL)
        
        let scraper = SmileyScraper(managedObjectContext: context)
        let ok = scraper.scrapeSmileys(HTML: archive.mainFrameHTML, error: &error)
        assert(ok, "scraping failed: \(error)")
        
        updater = SmileyUpdater(managedObjectContext: context, downloader: WebArchiveSmileyDownloader(archive))
        progress = updater.downloadMissingImageData()
        progress?.addObserver(self, forKeyPath: "completedUnitCount", options: nil, context: KVOContext)
    }
    
    override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
        if context == KVOContext {
            let progress = object as NSProgress
            if progress.completedUnitCount == progress.totalUnitCount {
                dispatch_async(dispatch_get_main_queue()) {
                    self.extractionDidFinish()
                }
            }
        } else {
            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
        }
    }
    
    private func extractionDidFinish() {
        context = nil
        updater = nil
        progress?.removeObserver(self, forKeyPath: "completedUnitCount", context: KVOContext)
        progress = nil
        let stores = storeCoordinator.persistentStores as [NSPersistentStore]
        for store in stores {
            var error: NSError?
            let ok = storeCoordinator.removePersistentStore(store, error: &error)
            assert(ok, "error removing store: \(error)")
        }
        replaceBarButtonItem.enabled = true
        pathTextView.text = storeURL.path
    }

    @IBAction func replaceExisting() {
        // this is a terrible idea
        let fileURL = NSURL.fileURLWithPath(__FILE__)!
        let smileysURL = fileURL.URLByDeletingLastPathComponent!.URLByDeletingLastPathComponent!
        let destinationURL = smileysURL.URLByAppendingPathComponent("BundledSmileys.sqlite")
        
        let filer = NSFileManager.defaultManager()
        filer.removeItemAtURL(destinationURL, error: nil)
        var error: NSError?
        let ok = filer.copyItemAtURL(storeURL, toURL: destinationURL, error: &error)
        assert(ok, "error copying item: \(error)")
        pathTextView.text = "\(pathTextView.text)\n\n\(destinationURL.path!)"
    }
}

private let KVOContext = UnsafeMutablePointer<Void>()

// SmileyDownloader is declared in SmileyFramework but there's some bridging header issues importing it into the Extractor app, and WebArchiveSmileyDownloader is directly included in the Extractor app, so redundantly declare conformance here.
extension WebArchiveSmileyDownloader: SmileyDownloader {}
