//  UpdaterTests.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Smilies
import XCTest

class UpdaterTests: XCTestCase {

    let fixture = WebArchive.loadFromFixture()
    
    var context: NSManagedObjectContext!
    var updater: SmilieUpdater!
    var smilie: Smilie!
    var expectation: XCTestExpectation?

    override func setUp() {
        super.setUp()
        context = inMemoryDataStack()
        updater = SmilieUpdater(managedObjectContext: context, downloader: WebArchiveSmilieDownloader(fixture))
    }
    
    override func tearDown() {
        if let smilie = smilie {
            smilie.removeObserver(self, forKeyPath: "imageData", context: nil)
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
            self.smilie = Smilie(managedObjectContext: self.context)
            self.smilie.text = ":wotwot:"
            self.smilie.imageURL = "http://i.somethingawful.com/forumsystem/emoticons/emot-wotwot.gif"
            self.smilie.addObserver(self, forKeyPath: "imageData", options: .New | .Old, context: nil)
            self.context.save(nil)
        }
    }

    func testUpdateOnInsert() {
        expectation = expectationWithDescription("Automatic image download")
        
        updater.automaticallyFetchNewSmilieImageData = true
        insertWotWotAndObserveImageData()
        
        waitForExpectationsWithTimeout(1) { error in
            XCTAssertNotNil(self.smilie!.imageData)
        }
    }

    func testDownloadMissingImageData() {
        expectation = expectationWithDescription("Manual image download")
        
        insertWotWotAndObserveImageData()
        updater.downloadMissingImageData()
        
        waitForExpectationsWithTimeout(1) { error in
            XCTAssertNotNil(self.smilie!.imageData)
        }
    }

}
