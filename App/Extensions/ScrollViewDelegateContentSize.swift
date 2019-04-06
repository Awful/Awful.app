//  ScrollViewDelegateContentSize.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
 Adds the private method `scrollViewDidChangeContentSize(_:)` to `UIScrollViewDelegate`.

 This is in preference to the usual approach for finding out when scroll views you don't control change their content size, which is using Key-Value Observing for the `contentSize` property.

 - Warning: This protocol uses undocumented, private API. It may change behavior or stop working entirely at any moment without warning.
 */
@objc protocol ScrollViewDelegateContentSize: UIScrollViewDelegate {

    /**
     Tells the delegate when the scroll view's content size changes.

     At least, that's how it seems to work. It's undocumented, private API, so who knows.

     - Warning: This is undocumented API. It seems to be present at least as far back as iOS 9.3, and it appears to be reliably called when the content size changes, but it is *undocumented*! It may not at all work how you expect. It may disappear in some point release of iOS. Be prepared for this to break at arbitrary times in unhelpful ways.
     */
    @objc optional func scrollViewDidChangeContentSize(_ scrollView: UIScrollView)
}
