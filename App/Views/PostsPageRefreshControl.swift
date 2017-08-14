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
        
        kvoController.observe(scrollView, keyPath: "contentSize", options: .initial) { [unowned self] _, _ in
            self.layoutScrollView()
        }
        
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(PostsPageRefreshControl.didPan(_:)))
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        scrollView.panGestureRecognizer.removeTarget(self, action: #selector(PostsPageRefreshControl.didPan(_:)))
    }
    
    func endRefreshing() {
        state = .waiting(triggeredFraction: 0)
    }
    
    fileprivate var content: PostsPageRefreshControlContent? {
        return contentView as? PostsPageRefreshControlContent
    }
    
    fileprivate func configureContentView() {
        content?.state = state
        
        contentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentView)
        
        contentView.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
        contentView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        
        scrollView.addSubview(self)
    }
    
    // MARK: State machine
    
    enum State {
        case waiting(triggeredFraction: CGFloat)
        case triggered
        case refreshing
        
        static func ==(lhs: State, rhs: State) -> Bool {
            switch (lhs, rhs) {
            case (.waiting(let fraction), .waiting(let otherFraction)):
                return fraction == otherFraction
            case (.triggered, .triggered):
                return true
            case (.refreshing, .refreshing):
                return true
            default:
                return false
            }
        }
    }
    
    fileprivate var state: State = .waiting(triggeredFraction: 0) {
        didSet { content?.state = state }
    }
    
    // MARK: Actions
    
    @objc fileprivate func didPan(_ sender: UIPanGestureRecognizer) {
        let maxVisibleY = scrollView.bounds.maxY - frame.height + bottomInset
        
        switch sender.state {
        case .began, .changed:
            switch state {
            case .waiting where maxVisibleY > frame.maxY:
                state = .triggered
                
            case .waiting, 
                 .triggered where maxVisibleY <= frame.maxY:
                let fraction = max((maxVisibleY - frame.minY) / frame.height, 0)
                state = .waiting(triggeredFraction: fraction)
            
            default:
                break
            }
            
        case .ended where state == .triggered:
            state = .refreshing
            
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [], animations: {
                self.bottomInset = self.height
                
                var contentOffset = self.scrollView.contentOffset
                contentOffset.y = self.frame.maxY - self.scrollView.bounds.height + self.scrollView.contentInset.bottom - self.height
                self.scrollView.contentOffset = contentOffset
                }, completion: nil)

            handler?()
            
        case .cancelled, .ended:
            state = .waiting(triggeredFraction: 0)
            bottomInset = 0
            
        default:
            break
        }
    }
    
    // MARK: Layout
    
    fileprivate func layoutScrollView() {
        let y = max(scrollView.contentSize.height, scrollView.bounds.height)
        frame = CGRect(x: 0, y: y, width: scrollView.bounds.width, height: height)
        
        switch state {
        case .refreshing:
            bottomInset = height
            
        default:
            bottomInset = 0
        }
    }
    
    override var intrinsicContentSize : CGSize {
        let contentHeight = contentView.systemLayoutSizeFitting(UILayoutFittingCompressedSize).height
        return CGSize(width: UIViewNoIntrinsicMetric, height: contentHeight + 2 * contentPadding)
    }
    
    fileprivate lazy var height: CGFloat = { [unowned self] in
        return self.intrinsicContentSize.height
        }()
    
    // MARK: Content inset
    
    fileprivate var bottomInset: CGFloat = 0 {
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
