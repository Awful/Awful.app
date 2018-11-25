//  PostsPageRefreshControl.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

private let Log = Logger.get()

final class PostsPageRefreshControl: UIView {
    private weak var scrollView: UIScrollView?
    var didStartRefreshing: (() -> Void)?
    
    var contentView: UIView {
        didSet {
            oldValue.removeFromSuperview()
            addContentView()
            layoutInScrollView()
        }
    }
    
    init(scrollView: UIScrollView, contentView: UIView) {
        self.scrollView = scrollView
        self.contentView = contentView
        
        super.init(frame: CGRect.zero)
        
        addContentView()
        
        scrollView.addDelegate(self)
    }
    
    deinit {
        scrollView?.removeDelegate(self)
    }
    
    func endRefreshing() {
        switch state {
        case .armed, .awaitingScrollEnd, .triggered, .refreshing:
            state = .ready
            
        case .ready:
            break
        }
    }
    
    private var content: PostsPageRefreshControlContent? {
        return contentView as? PostsPageRefreshControlContent
    }
    
    private func addContentView() {
        content?.state = state
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor)])
        
        scrollView?.addSubview(self)
    }
    
    // MARK: State machine
    
    enum State: Equatable {
        
        /// The refresh control may spring to life if an appropriate drag begins.
        case ready
        
        /**
         The refresh control is reacting to continued dragging and may end up triggering a refresh.
         
         `triggeredFraction` is how close the control is to triggering a refresh. It is for the benefit of the content view (e.g. to spin an arrow around interactively during scrolling) and is not used by the control itself.
         */
        case armed(triggeredFraction: CGFloat)
        
        /**
         A drag began too far away for the refresh control to spring to life, so we'll wait for dragging to finish before getting ready for the next one.
         
         This state avoids accidentally triggering a refresh when the user is rapidly (and probably coarsely) scrolling down.
         */
        case awaitingScrollEnd
        
        /// If the drag stops here, a refresh is triggered.
        case triggered
        
        /// A refresh has been triggered, the handler has been called, and a refreshing animation should continue until `endRefreshing()` is called.
        case refreshing
    }
    
    private var state: State = .ready {
        willSet {
            switch (state, newValue) {
            case (.ready, .armed),
                 (.ready, .awaitingScrollEnd),
                 (.ready, .triggered):
                break
                
            case (.armed, .armed),
                 (.armed, .awaitingScrollEnd),
                 (.armed, .triggered),
                 (.armed, .ready):
                break
                
            case (.awaitingScrollEnd, .ready):
                break
                
            case (.triggered, .armed),
                 (.triggered, .awaitingScrollEnd),
                 (.triggered, .refreshing):
                break
                
            case (.refreshing, .ready):
                break
                
            case (.ready, _),
                 (.armed, _),
                 (.awaitingScrollEnd, _),
                 (.triggered, _),
                 (.refreshing, _):
                assertionFailure("attempted invalid state transition from \(state) to \(newValue)")
            }
        }
        didSet {
            Log.d("transitioned from \(oldValue) to \(state)")
            
            content?.state = state
            
            switch state {
            case .ready, .awaitingScrollEnd:
                layoutInScrollView()
                
            case .refreshing:
                layoutInScrollView()
                didStartRefreshing?()
                
                if let scrollView = scrollView, !scrollView.isDragging {
                    var contentOffset = scrollView.contentOffset
                    contentOffset.y = max(scrollView.contentSize.height, scrollView.bounds.height)
                        - scrollView.bounds.height
                        + intrinsicContentSize.height
                    scrollView.setContentOffset(contentOffset, animated: true)
                }
                
            case .armed, .triggered:
                break
            }
        }
    }
    
    // MARK: Layout
    
    private func layoutInScrollView() {
        guard let scrollView = scrollView else { return }
        
        let y = max(scrollView.contentSize.height, scrollView.bounds.height)
        frame = CGRect(x: 0, y: y, width: scrollView.bounds.width, height: intrinsicContentSize.height)
        
        bottomInset = {
            switch state {
            case .refreshing:
                return intrinsicContentSize.height
                
            case .ready, .armed, .awaitingScrollEnd, .triggered:
                return 0
            }
        }()
    }
    
    override var intrinsicContentSize: CGSize {
        let contentPadding: CGFloat = 10
        let contentHeight = contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        return CGSize(width: UIView.noIntrinsicMetric, height: contentHeight + 2 * contentPadding)
    }
    
    // MARK: Content inset
    
    private var bottomInset: CGFloat = 0 {
        didSet {
            if bottomInset != oldValue, let scrollView = scrollView {
                scrollView.contentInset.bottom += bottomInset - oldValue
            }
        }
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension PostsPageRefreshControl: ScrollViewDelegateExtras {
    func scrollViewDidChangeContentSize(_ scrollView: UIScrollView) {
        layoutInScrollView()
    }
    
    private struct ScrollViewInfo {
        let effectiveContentHeight: CGFloat
        let refreshControlHeight: CGFloat
        let targetScrollViewBoundsMaxY: CGFloat
        
        init(refreshControlHeight: CGFloat, scrollView: UIScrollView, targetContentOffset: CGPoint? = nil) {
            var contentInsetBottom: CGFloat {
                if #available(iOS 11.0, *) {
                    return scrollView.adjustedContentInset.bottom
                } else {
                    return scrollView.contentInset.bottom
                }
            }
            
            effectiveContentHeight = max(scrollView.contentSize.height + contentInsetBottom, scrollView.bounds.height)
            self.refreshControlHeight = refreshControlHeight
            targetScrollViewBoundsMaxY = (targetContentOffset?.y ?? scrollView.contentOffset.y) + scrollView.bounds.height
        }
        
        static let closeEnoughToBottom: CGFloat = -50
        
        var visibleBottom: CGFloat {
            return targetScrollViewBoundsMaxY - effectiveContentHeight
        }
        
        var triggeredFraction: CGFloat {
            return max(visibleBottom / refreshControlHeight, 0)
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        let info = ScrollViewInfo(refreshControlHeight: intrinsicContentSize.height, scrollView: scrollView)
        
        switch state {
        case .ready:
            // Don't want to trigger if the user is doing mad successive drags to get quickly to the bottom.
            guard !scrollView.isDecelerating else { break }
            
            if info.visibleBottom >= ScrollViewInfo.closeEnoughToBottom {
                state = .armed(triggeredFraction: info.triggeredFraction)
            } else {
                state = .awaitingScrollEnd
            }
            
        case .armed:
            if info.triggeredFraction >= 1 {
                state = .triggered
            } else {
                state = .armed(triggeredFraction: info.triggeredFraction)
            }
            
        case .awaitingScrollEnd, .triggered, .refreshing:
            break
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let info = ScrollViewInfo(refreshControlHeight: intrinsicContentSize.height, scrollView: scrollView)
        
        switch state {
        case .armed(let triggeredFraction):
            if info.triggeredFraction >= 1 {
                state = .triggered
            } else if info.triggeredFraction != triggeredFraction {
                state = .armed(triggeredFraction: info.triggeredFraction)
            }
            
        case .triggered:
            if info.triggeredFraction < 1 {
                state = .armed(triggeredFraction: info.triggeredFraction)
            }
            
        case .ready, .awaitingScrollEnd, .refreshing:
            break
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate: Bool) {
        switch state {
        case .awaitingScrollEnd where !willDecelerate:
            state = .ready
            
        case .armed where !willDecelerate:
            state = .awaitingScrollEnd
            
        case .triggered:
            state = .refreshing
            
        case .ready, .armed, .awaitingScrollEnd, .refreshing:
            break
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        switch state {
        case .awaitingScrollEnd:
            state = .ready
            
        case .ready, .armed, .triggered, .refreshing:
            break
        }
    }
}

/// A type that can react to changes in posts page refresh control state.
protocol PostsPageRefreshControlContent: class {
    var state: PostsPageRefreshControl.State { get set }
}
