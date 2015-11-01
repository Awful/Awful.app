//  PostsPageRefreshControl.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import KVOController
import UIKit

private let contentPadding: CGFloat = 10

final class PostsPageRefreshControl: UIView {
    unowned let scrollView: UIScrollView
    var handler: (() -> Void)?
    
    var contentView: UIView {
        didSet {
            oldValue.removeFromSuperview()
            configureContentView()
            layoutScrollView()
        }
    }
    
    init(scrollView: UIScrollView, contentView: UIView) {
        self.scrollView = scrollView
        self.contentView = contentView
        
        super.init(frame: CGRect.zero)
        
        configureContentView()
        
        KVOController.observe(scrollView, keyPath: "contentSize", options: .Initial) { [unowned self] _, _ in
            self.layoutScrollView()
        }
        
        scrollView.panGestureRecognizer.addTarget(self, action: "didPan:")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        scrollView.panGestureRecognizer.removeTarget(self, action: "didPan:")
    }
    
    func endRefreshing() {
        state = .Waiting(triggeredFraction: 0)
    }
    
    private var content: PostsPageRefreshControlContent? {
        return contentView as? PostsPageRefreshControlContent
    }
    
    private func configureContentView() {
        content?.state = state
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        
        contentView.centerXAnchor.constraintEqualToAnchor(centerXAnchor).active = true
        contentView.centerYAnchor.constraintEqualToAnchor(centerYAnchor).active = true
        
        scrollView.addSubview(self)
    }
    
    // MARK: State machine
    
    enum State {
        case Waiting(triggeredFraction: CGFloat)
        case Triggered
        case Refreshing
    }
    
    private var state: State = .Waiting(triggeredFraction: 0) {
        didSet { content?.state = state }
    }
    
    // MARK: Actions
    
    @objc private func didPan(sender: UIPanGestureRecognizer) {
        let maxVisibleY = scrollView.bounds.maxY - scrollView.contentInset.bottom + bottomInset
        
        switch sender.state {
        case .Began, .Changed:
            switch state {
            case .Waiting where maxVisibleY > frame.maxY:
                state = .Triggered
                
            case (.Waiting), .Triggered where maxVisibleY <= frame.maxY:
                let fraction = max((maxVisibleY - frame.minY) / frame.height, 0)
                state = .Waiting(triggeredFraction: fraction)
            
            default:
                break
            }
            
        case .Ended where maxVisibleY > frame.maxY:
            state = .Refreshing
            
            UIView.animateWithDuration(0.2, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: {
                self.bottomInset = self.height
                
                var contentOffset = self.scrollView.contentOffset
                contentOffset.y = self.frame.maxY - self.scrollView.bounds.height + self.scrollView.contentInset.bottom - self.height
                self.scrollView.contentOffset = contentOffset
                }, completion: nil)

            handler?()
            
        case .Cancelled, .Ended:
            state = .Waiting(triggeredFraction: 0)
            bottomInset = 0
            
        default:
            break
        }
    }
    
    // MARK: Layout
    
    private func layoutScrollView() {
        let y = max(scrollView.contentSize.height, scrollView.bounds.height)
        frame = CGRect(x: 0, y: y, width: scrollView.bounds.width, height: height)
        
        switch state {
        case .Refreshing:
            bottomInset = height
            
        default:
            bottomInset = 0
        }
    }
    
    override func intrinsicContentSize() -> CGSize {
        let contentHeight = contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize).height
        return CGSize(width: UIViewNoIntrinsicMetric, height: contentHeight + 2 * contentPadding)
    }
    
    private lazy var height: CGFloat = { [unowned self] in
        return self.intrinsicContentSize().height
        }()
    
    // MARK: Content inset
    
    private var bottomInset: CGFloat = 0 {
        didSet {
            if bottomInset != oldValue {
                scrollView.contentInset.bottom += bottomInset - oldValue
            }
        }
    }
}

/// A type that can react to changes in posts page refresh control state.
protocol PostsPageRefreshControlContent: class {
    var state: PostsPageRefreshControl.State { get set }
}
