//  SmileyKeyboardViewController.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import MobileCoreServices
import Smileys
import UIKit

class SmileyKeyboardViewController: UIInputViewController {

    private var keyboardView: SmileyKeyboardView!
    private var dataStack: SmileyDataStack!
    private var resultsController: NSFetchedResultsController!
    private var currentSection: Int = 0 {
        didSet(oldSection) {
            if oldSection != currentSection {
                keyboardView.reloadData()
            }
        }
    }
    
    override func loadView() {
        super.loadView()
        
        keyboardView = SmileyKeyboardView(frame: CGRectZero)
        keyboardView.delegate = self
        keyboardView.setTranslatesAutoresizingMaskIntoConstraints(false)
        view.addSubview(keyboardView)
        
        let views = ["keyboard": keyboardView]
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[keyboard]|", options: nil, metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[keyboard]|", options: nil, metrics: nil, views: views))
        
        keyboardView.nextKeyboardButton.addTarget(self, action: "advanceToNextInputMode", forControlEvents: .TouchUpInside)
        keyboardView.sectionPicker.addTarget(self, action: "didTapSectionPicker:", forControlEvents: .ValueChanged)
        keyboardView.deleteButton.addTarget(self, action: "deleteBackward", forControlEvents: .TouchUpInside)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tintColor = UIColor.blackColor()
        view.tintColor = tintColor
        keyboardView.deleteButton.setTitleColor(tintColor, forState: .Normal)
        
        dataStack = SmileyDataStack()
        let fetchRequest = NSFetchRequest(entityName: "Smiley")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "section", ascending: true),
            NSSortDescriptor(key: "text", ascending: true)
        ]
        fetchRequest.predicate = NSPredicate(format: "imageData != nil")
        fetchRequest.fetchBatchSize = 50
        resultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: dataStack.managedObjectContext, sectionNameKeyPath: "section", cacheName: nil)
        resultsController.delegate = self
        var error: NSError?
        let ok = resultsController.performFetch(&error)
        assert(ok, "error fetching smilies: \(error)")
        reloadSectionInfo()
    }
    
    @objc private func didTapSectionPicker(sender: UISegmentedControl) {
        currentSection = sender.selectedSegmentIndex
    }
    
    @objc private func deleteBackward() {
        let keyInput = textDocumentProxy as UIKeyInput
        keyInput.deleteBackward()
    }

}

extension SmileyKeyboardViewController: SmileyKeyboardViewDelegate {
    func numberOfKeysInSmileyKeyboard(keyboardView: SmileyKeyboardView) -> Int {
        let sections = resultsController.sections as [NSFetchedResultsSectionInfo]
        return sections[currentSection].numberOfObjects
    }
    
    func smileyKeyboard(keyboardView: SmileyKeyboardView, imageDataForKeyAtIndexPath indexPath: NSIndexPath) -> NSData {
        let smiley = resultsController.objectAtIndexPath(NSIndexPath(forItem: indexPath.item, inSection: currentSection)) as Smiley
        return smiley.imageData!
    }
    
    func smileyKeyboard(keyboardView: SmileyKeyboardView, didTapKeyAtIndexPath indexPath: NSIndexPath) {
        let smiley = resultsController.objectAtIndexPath(NSIndexPath(forItem: indexPath.item, inSection: currentSection)) as Smiley
        let data = smiley.imageData!
        // GIFs start with the string "GIF", and nothing else starts with "G".
        var firstByte: UInt8 = 0
        data.getBytes(&firstByte, length: 1)
        if firstByte == 0x47 {
            UIPasteboard.generalPasteboard().setData(data, forPasteboardType: kUTTypeGIF as NSString)
        } else {
            UIPasteboard.generalPasteboard().image = UIImage(data: data)
        }
    }
}

extension SmileyKeyboardViewController: NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(controller: NSFetchedResultsController) {
        keyboardView.reloadData()
        reloadSectionInfo()
    }
    
    private func reloadSectionInfo() {
        keyboardView.sectionPicker.removeAllSegments()
        for (i, section) in enumerate(resultsController.sections as [NSFetchedResultsSectionInfo]) {
            let abbreviation = String(section.name[section.name.startIndex]) as NSString
            abbreviation.accessibilityLabel = section.name
            keyboardView.sectionPicker.insertSegmentWithTitle(abbreviation, atIndex: i, animated: false)
        }
        keyboardView.sectionPicker.selectedSegmentIndex = currentSection
    }
}
