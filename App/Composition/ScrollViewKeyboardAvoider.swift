//  ScrollViewKeyboardAvoider.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Sets a scroll view's bottom insets to avoid the keyboard.
final class ScrollViewKeyboardAvoider {
    fileprivate var observer: AnyObject!
    
    init(_ scrollView: UIScrollView) {
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIKeyboardWillChangeFrame, object: nil, queue: OperationQueue.main) { [unowned self] note in
            self.keyboardWillChangeFrame(note, scrollView: scrollView)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(observer)
    }
    
    fileprivate func keyboardWillChangeFrame(_ note: Notification, scrollView: UIScrollView) {
        if let window = scrollView.window {
            let screenFrame = ((note as NSNotification).userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
            let localFrame = scrollView.superview!.convert(screenFrame, from: window.screen.coordinateSpace)
            let intersection = localFrame.intersection(scrollView.frame)
            let bottomInset = intersection.isNull ? 0 : intersection.height
            
            let duration = (note as NSNotification).userInfo![UIKeyboardAnimationDurationUserInfoKey] as! TimeInterval
            let rawCurve = (note as NSNotification).userInfo![UIKeyboardAnimationCurveUserInfoKey] as! Int
            let options = UIViewAnimationOptions(rawValue: UInt(rawCurve) << 16)
            UIView.animate(withDuration: duration, delay: 0, options: options, animations: {
                scrollView.contentInset.bottom = bottomInset
                scrollView.scrollIndicatorInsets.bottom = bottomInset
                }, completion: nil)
        }
    }
}
