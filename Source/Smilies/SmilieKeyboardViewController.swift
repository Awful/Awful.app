//  SmilieKeyboardViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import MobileCoreServices
import Smilies
import UIKit

class SmilieKeyboardViewController: UIInputViewController {

    lazy private var keyboardView: SmilieKeyboardView = {
        let nibObjects = NSBundle(forClass: SmilieKeyboardView.self).loadNibNamed("KeyboardView", owner: nil, options: nil)
        return nibObjects[0] as SmilieKeyboardView
        }()
    
    lazy private var dataStack = SmilieDataStack()
    
    lazy private var resultsController: NSFetchedResultsController = { [unowned self] in
        let fetchRequest = NSFetchRequest(entityName: "Smilie")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "section", ascending: true),
            NSSortDescriptor(key: "text", ascending: true)
        ]
        fetchRequest.predicate = NSPredicate(format: "imageData != nil")
        fetchRequest.fetchBatchSize = 50
        let resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.dataStack.managedObjectContext, sectionNameKeyPath: "section", cacheName: nil)
        resultsController.delegate = self
        return resultsController
        }()
    
    
    override func loadView() {
        super.loadView()
        
        keyboardView.delegate = self
        view.addSubview(keyboardView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        var error: NSError?
        let ok = resultsController.performFetch(&error)
        assert(ok, "error fetching smilies: \(error)")
    }
    
}

extension SmilieKeyboardViewController: SmilieKeyboardViewDelegate {
    
    func numberOfSectionsInSmilieKeyboard(keyboardView: SmilieKeyboardView) -> Int {
        return resultsController.sections!.count
    }
    
    func smilieKeyboard(keyboardView: SmilieKeyboardView, titleForSection section: Int) -> NSString {
        let sections = resultsController.sections as [NSFetchedResultsSectionInfo]
        let sectionInfo = sections[section]
        let abbreviation = String(sectionInfo.name[sectionInfo.name.startIndex]) as NSString
        abbreviation.accessibilityLabel = sectionInfo.name
        return abbreviation
    }
    
    func smilieKeyboard(keyboardView: SmilieKeyboardView, numberOfKeysInSection section: Int) -> Int {
        let sections = resultsController.sections as [NSFetchedResultsSectionInfo]
        return sections[section].numberOfObjects
    }
    
    func smilieKeyboard(keyboardView: SmilieKeyboardView, imageDataForKeyAtIndexPath indexPath: NSIndexPath) -> NSData {
        let smilie = resultsController.objectAtIndexPath(indexPath) as Smilie
        return smilie.imageData!
    }
    
    func smilieKeyboard(keyboardView: SmilieKeyboardView, didTapKeyAtIndexPath indexPath: NSIndexPath) {
        let smilie = resultsController.objectAtIndexPath(indexPath) as Smilie
        let data = smilie.imageData!
        // GIFs start with the string "GIF", and nothing else starts with "G".
        var firstByte: UInt8 = 0
        data.getBytes(&firstByte, length: 1)
        if firstByte == 0x47 {
            UIPasteboard.generalPasteboard().setData(data, forPasteboardType: kUTTypeGIF as NSString)
        } else {
            UIPasteboard.generalPasteboard().image = UIImage(data: data)
        }
    }
    
    func deleteBackwardForSmilieKeyboard(keyboardView: SmilieKeyboardView) {
        let keyInput = textDocumentProxy as UIKeyInput
        keyInput.deleteBackward()
    }
    
    func advanceToNextKeyboardFromSmilieKeyboard(keyboardView: SmilieKeyboardView) {
        advanceToNextInputMode()
    }

}

extension SmilieKeyboardViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        keyboardView.reloadData()
    }
}
