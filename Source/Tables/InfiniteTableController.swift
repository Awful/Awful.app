//  InfiniteTableController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Triggers loading more content and showing a spinner in a table view's tableFooterView when scrolling past the end of a table.
final class InfiniteTableController {
    /// Called when more contents should be loaded into the table.
    typealias MoreLoader = () -> Void
    
    private let tableView: UITableView
    private let loadMore: MoreLoader
    private let footerView = TableFooterView(frame: CGRect(x: 0, y: 0, width: 0, height: 45))
    var enabled = true
    
    var spinnerColor: UIColor? {
        get { return footerView.spinner.color }
        set { footerView.spinner.color = newValue }
    }
    
    init(tableView: UITableView, loadMore: MoreLoader) {
        self.tableView = tableView
        self.loadMore = loadMore
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private enum State {
        /// Nothing animated, nothing in tableFooterView.
        case Ready
        
        /// Spinner animated, tableFooterView is set, letting go of the scroll view will call loadMore.
        case Set
        
        /// loadMore was called, awaiting stop() call.
        case Go
    }
    
    private var state: State = .Ready {
        didSet(priorState) {
            if priorState == state { return }
            
            switch state {
            case .Ready:
                footerView.stopAnimating()
                tableView.tableFooterView = nil
            case .Set, .Go:
                footerView.startAnimating()
                tableView.tableFooterView = footerView
            }
        }
    }
    
    /// Programmatically start the spinner. Does not call loadMore. Be sure to call stop() when finished.
    func start() {
        state = .Go
    }
    
    /// Stop the spinner and shrink into oblivion.
    func stop() {
        state = .Ready
    }
    
    /// Please forward this UIScrollViewDelegate method from your UITableViewDelegate.
    func scrollViewDidScroll(scrollView: UIScrollView) {
        if !enabled { return }
        
        let threshold = scrollView.contentSize.height - scrollView.bounds.height
        switch state {
        case .Ready:
            if scrollView.contentOffset.y > threshold {
                state = .Set
            }
        case .Set:
            if scrollView.contentOffset.y > threshold {
                if !scrollView.dragging {
                    state = .Go
                    loadMore()
                }
            } else {
                state = .Ready
            }
        case .Go:
            break
        }
    }
    
    private final class TableFooterView: UIView {
        let spinner: UIActivityIndicatorView = {
            let spinner = UIActivityIndicatorView()
            spinner.hidesWhenStopped = true
            return spinner
            }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            addSubview(spinner)
        }

        required init(coder aDecoder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private override func didMoveToSuperview() {
            if let superview = superview {
                frame.size.width = superview.bounds.width
            }
        }
        
        private override func layoutSubviews() {
            spinner.center = CGPoint(x: CGRectGetMidX(bounds), y: CGRectGetMidY(bounds))
        }
        
        func startAnimating() {
            spinner.startAnimating()
        }
        
        func stopAnimating() {
            spinner.stopAnimating()
        }
    }
}
