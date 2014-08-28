//  UIAlertController+AwfulConvenient.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

extension UIAlertController {
    class func alertWithTitle(title: String, error: NSError, handler: (action: UIAlertAction!) -> Void) -> UIAlertController {
        return informationalAlertWithTitle(title, message: messageForError(error), handler: handler)
    }

    class func alertWithTitle(title: String, error: NSError) -> UIAlertController {
        return informationalAlertWithTitle(title, message: messageForError(error), handler: nil)
    }

    class func alertWithNetworkError(error: NSError) -> UIAlertController {
        return alertWithTitle("Network Error", error: error)
    }

    class func informationalAlertWithTitle(title: String, message: String, handler: ((action: UIAlertAction!) -> Void)!) -> UIAlertController {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert);
        alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: handler))
        return alert
    }

    class func informationalAlertWithTitle(title: String, message: String) -> UIAlertController {
        return informationalAlertWithTitle(title, message: message, handler: nil)
    }
}

private func messageForError(error: NSError) -> String {
    return "\(error.localizedDescription) (code \(error.code))"
}
