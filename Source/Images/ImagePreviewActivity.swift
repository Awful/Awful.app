//  ImagePreviewActivity.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Takes the last NSURL activity item and shows it in an ImageViewController.
class ImagePreviewActivity: UIActivity {
    private(set) var activityViewController: UIViewController!
    
    override func activityType() -> String? {
        return "com.awfulapp.Awful.ImagePreview"
    }
    
    override func activityTitle() -> String? {
        return "Preview Image"
    }
    
    override func activityImage() -> UIImage? {
        return UIImage(named: "quick-look")
    }
    
    override func canPerformWithActivityItems(activityItems: [AnyObject]) -> Bool {
        return any(activityItems) { item in item is NSURL }
    }
    
    override func prepareWithActivityItems(activityItems: [AnyObject]) {
        let imageURL = first(activityItems.reverse()) { item in item is NSURL } as NSURL
        let imageViewController = ImageViewController(URL: imageURL)
        imageViewController.doneAction = { self.activityDidFinish(true) }
        activityViewController = imageViewController
    }
}

func any<S: SequenceType, T where T == S.Generator.Element>(sequence: S, includeElement: (T) -> Bool) -> Bool {
    return first(sequence, includeElement) != nil
}

func first<S: SequenceType, T where T == S.Generator.Element>(sequence: S, includeElement: (T) -> Bool) -> T? {
    for element in sequence {
        if includeElement(element) {
            return element
        }
    }
    return nil
}
