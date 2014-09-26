//  UpdaterTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Smileys
import XCTest

class UpdaterTests: XCTestCase {

    let fixture = WebArchive.loadFromFixture()
    
    var context: NSManagedObjectContext!
    var updater: SmileyUpdater!
    var smiley: Smiley!
    var expectation: XCTestExpectation?

    override func setUp() {
        super.setUp()
        context = inMemoryDataStack()
        updater = SmileyUpdater(managedObjectContext: context, downloader: WebArchiveSmileyDownloader(fixture))
    }
    
    override func tearDown() {
        if let smiley = smiley {
            smiley.removeObserver(self, forKeyPath: "imageData", context: nil)
        }
        super.tearDown()
    }
    
    override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [NSObject : AnyObject]!, context: UnsafeMutablePointer<Void>) {
        if let newValue = change[NSKeyValueChangeNewKey] as? NSData {
            expectation?.fulfill()
        }
    }
    
    func insertWotWotAndObserveImageData() {
        context.performBlock {
            self.smiley = Smiley(managedObjectContext: self.context)
            self.smiley.text = ":wotwot:"
            self.smiley.imageURL = "http://i.somethingawful.com/forumsystem/emoticons/emot-wotwot.gif"
            self.smiley.addObserver(self, forKeyPath: "imageData", options: .New | .Old, context: nil)
            self.context.save(nil)
        }
    }

    func testUpdateOnInsert() {
        expectation = expectationWithDescription("Automatic image download")
        
        updater.automaticallyFetchNewSmileyImageData = true
        insertWotWotAndObserveImageData()
        
        waitForExpectationsWithTimeout(1) { error in
            XCTAssertNotNil(self.smiley!.imageData)
        }
    }

    func testDownloadMissingImageData() {
        expectation = expectationWithDescription("Manual image download")
        
        insertWotWotAndObserveImageData()
        updater.downloadMissingImageData()
        
        waitForExpectationsWithTimeout(1) { error in
            XCTAssertNotNil(self.smiley!.imageData)
        }
    }

}

class WebArchiveSmileyDownloader: SmileyDownloader {
    let archive: WebArchive
    
    init(_ archive: WebArchive) {
        self.archive = archive
    }
    
    func downloadImageDataFromURL(URL: NSURL, completionBlock: (imageData: NSData!, error: NSError!) -> Void) {
        let imageData = archive.dataForSubresourceWithURL(URL.absoluteString!)
        let error: NSError? = imageData == nil ? NSError(domain: "SmileyErrorDomain", code: 2, userInfo: nil) : nil
        completionBlock(imageData: imageData, error: error)
    }
}
