//  ScrollViewKeyboardAvoider.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Sets a scroll view's bottom insets to avoid the keyboard.
final class ScrollViewKeyboardAvoider {
    private var observer: AnyObject!
    
    init(_ scrollView: UIScrollView) {
        observer = NSNotificationCenter.defaultCenter().addObserverForName(UIKeyboardWillChangeFrameNotification, object: nil, queue: NSOperationQueue.mainQueue()) { [unowned self] note in
            self.keyboardWillChangeFrame(note, scrollView: scrollView)
        }
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(observer)
    }
    
    private func keyboardWillChangeFrame(note: NSNotification, scrollView: UIScrollView) {
        if let window = scrollView.window {
            let screenFrame = (note.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
            let localFrame = scrollView.superview!.convertRect(screenFrame, fromCoordinateSpace: window.screen.coordinateSpace)
            let intersection = CGRectIntersection(localFrame, scrollView.frame)
            let bottomInset = CGRectIsNull(intersection) ? 0 : intersection.height
            
            let duration = note.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! NSTimeInterval
            let rawCurve = note.userInfo![UIKeyboardAnimationCurveUserInfoKey] as! Int
            let options = UIViewAnimationOptions(rawValue: UInt(rawCurve) << 16)
            UIView.animateWithDuration(duration, delay: 0, options: options, animations: {
                scrollView.contentInset.bottom = bottomInset
                scrollView.scrollIndicatorInsets.bottom = bottomInset
                }, completion: nil)
        }
    }
}
