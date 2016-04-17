//  PostsView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/**
    Wraps a UIWebView and emulates a top contentInset, to which UIWebView reacts poorly.
 
    Specifically, when a UIWebView has a contentInset, elements' bounding rects seem to be adjusted but `document.elementFromPoint` doesn't consider this. Since it returns null if either argument is negative, some visible elements will never be returned. rdar://problem/16925474
 
    We want to use a top contentInset for showing the top bar. Since that won't work, an AwfulPostsView will fake it for us.
 */
final class PostsView: UIView {
    let webView = UIWebView.nativeFeelingWebView()
    let topBar = PostsViewTopBar()
    private var exposedTopBarSlice: CGFloat = 0 {
        didSet {
            if oldValue != exposedTopBarSlice {
                setNeedsLayout()
            }
        }
    }
    private var ignoreScrollViewDidScroll = false
    private var lastContentOffset: CGPoint = .zero
    private var maintainTopBarState = true
    private var topBarAlwaysVisible = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        webView.backgroundColor = nil
        webView.scrollView.delegate = self
        addSubview(webView)
        
        addSubview(topBar)
        
        updateForVoiceOver(animated: false)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(voiceOverStatusDidChange), name: UIAccessibilityVoiceOverStatusChanged, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func voiceOverStatusDidChange(notification: NSNotification) {
        updateForVoiceOver(animated: true)
    }
    
    private func updateForVoiceOver(animated animated: Bool) {
        topBarAlwaysVisible = UIAccessibilityIsVoiceOverRunning()
        guard topBarAlwaysVisible else { return }
        exposedTopBarSlice = topBar.bounds.height
        UIView.animateWithDuration(animated ? 0.2 : 0) { 
            self.layoutIfNeeded()
        }
    }
    
    private func furtherExposeTopBarSlice(delta: CGFloat) {
        let oldExposedSlice = exposedTopBarSlice
        exposedTopBarSlice = (exposedTopBarSlice + delta).clamp(0, topBar.bounds.height)
        let exposedDelta = exposedTopBarSlice - oldExposedSlice
        
        ignoreScrollViewDidScroll = true
        webView.scrollView.contentOffset.y = max(webView.scrollView.contentOffset.y + exposedDelta, 0)
        ignoreScrollViewDidScroll = false
    }
    
    override func layoutSubviews() {
        let fractionalOffset = webView.fractionalContentOffset
        
        var topBarFrame = topBar.bounds
        topBarFrame.origin.y = exposedTopBarSlice - topBarFrame.height
        topBarFrame.size.width = bounds.width
        topBar.frame = topBarFrame
        
        /*
            This silliness combats an annoying interplay on iOS 8 between UISplitViewController and UIWebView. On a 2x Retina iPad in landscape with the sidebar always visible, the width is distributed like so:
         
                       separator(0.5)
            |--sidebar(350)--|------------posts(673.5)------------|
         
            Unfortunately, UIWebView doesn't particularly like a fractional portion to its width, and it will round up its content size to 674 in this example. And now that the content is wider than the viewport, we get horizontal scrolling.
         
            (And if you ask UISplitViewController to set a maximumPrimaryColumnWidth of, say, 349.5 to take the separator into account, it will simply round down to 349.)
         */
        let integralWidth = CGFloat(floor(bounds.width))
        let fractionalPart = bounds.width - integralWidth
        webView.frame = CGRect(x: fractionalPart, y: topBarFrame.maxY, width: integralWidth, height: bounds.height - exposedTopBarSlice)
        
        /**
            When the app enters the background, on iPad, the width of the view changes dramatically while the system takes a snapshot. The end result is that when you leave Awful then come back, you're scrolled away from where you actually were when you left. Here we try to combat that.
         
            That said, if we're in the middle of dragging, messing with contentOffset just makes scrolling janky.
         */
        if !webView.scrollView.dragging {
            webView.fractionalContentOffset = fractionalOffset
        }
    }
}

private enum TopBarState {
    case Hidden, Visible, PartiallyVisible
}

extension PostsView {
    private var topBarState: TopBarState {
        if exposedTopBarSlice <= 0 {
            return .Hidden
        } else if exposedTopBarSlice >= topBar.bounds.height {
            return .Visible
        } else {
            return .PartiallyVisible
        }
    }
}

extension PostsView: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        lastContentOffset = scrollView.contentOffset
        maintainTopBarState = false
    }
    
    func scrollViewDidScroll(scrollView: UIScrollView) {
        guard !ignoreScrollViewDidScroll && !topBarAlwaysVisible else { return }
        
        let scrollDistance = scrollView.contentOffset.y - lastContentOffset.y
        guard scrollDistance != 0 else { return }
        
        switch topBarState {
        case .Hidden:
            // Don't start showing a hidden topbar after bouncing.
            guard !maintainTopBarState else { break }
            
            // Only moving the content down can expose the topbar.
            guard scrollDistance < 0 else { break }
            
            // Only start showing the topbar if we're scrolling past the bottom of the scrollview's contents. Otherwise we can briefly trap ourselves at the bottom, exposing some topbar causing the scrollview to bounce back.
            if scrollView.bounds.maxY - scrollView.contentInset.bottom - scrollDistance <= scrollView.contentSize.height {
                furtherExposeTopBarSlice(-scrollDistance)
            }
            
        case .PartiallyVisible:
            furtherExposeTopBarSlice(-scrollDistance)
            
        case .Visible:
            // Don't start hiding a visible topbar after bouncing.
            guard !maintainTopBarState else { break }
            
            // Only start hiding the topbar if we're scrolling past the top of the scrollview's contents. Otherwise we can briefly trap ourselves at the top, hiding some topbar causing the scrollview to bounce back.
            guard scrollView.contentOffset.y >= 0 else { break }
            
            // Only moving the content up can hide the topbar.
            if scrollDistance > 0 {
                furtherExposeTopBarSlice(-scrollDistance)
            }
        }
        
        lastContentOffset = scrollView.contentOffset
    }
    
    func scrollViewWillBeginDecelerating(scrollView: UIScrollView) {
        maintainTopBarState = true
    }
    
    func scrollViewShouldScrollToTop(scrollView: UIScrollView) -> Bool {
        maintainTopBarState = true
        return true
    }
}
