//  LoadMoreFooter.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class LoadMoreFooter: NSObject {
    
    private let loadMore: (LoadMoreFooter) -> Void
    private let tableView: UITableView
    
    private enum State {
        case ready, loading
    }
    
    private var state: State = .ready {
        didSet {
            switch (oldValue, state) {
            case (.ready, .loading):
                themeDidChange()
                refreshView.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: tableView.bounds.width,
                    height: refreshView.intrinsicContentSize.height)
                refreshView.startAnimating()
                tableView.tableFooterView = refreshView
                
                loadMore(self)
                
            case (.loading, .ready):
                if tableView.tableFooterView == refreshView {
                    tableView.tableFooterView = nil
                }
                refreshView.stopAnimating()
                
            case (.ready, _), (.loading, _):
                break
            }
        }
    }
    
    private lazy var refreshView = NigglyRefreshView()
    
    init(tableView: UITableView, multiplexer: ScrollViewDelegateMultiplexer, loadMore: @escaping (LoadMoreFooter) -> Void) {
        self.loadMore = loadMore
        self.tableView = tableView
        super.init()
        
        multiplexer.addDelegate(self)
    }
    
    deinit {
        removeFromTableView()
    }
    
    func didFinish() {
        switch state {
        case .loading:
            state = .ready
            
        case .ready:
            break
        }
    }
    
    func removeFromTableView() {
        if tableView.tableFooterView == refreshView {
            tableView.tableFooterView = nil
        }
    }

    func themeDidChange() {
        refreshView.backgroundColor = tableView.backgroundColor
    }
    
    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension LoadMoreFooter: UITableViewDelegate {
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        
        assert(scrollView === tableView)
        
        var proximityToBottom: CGFloat {
            return scrollView.contentSize.height - (targetContentOffset.pointee.y + scrollView.bounds.height)
        }
        
        switch state {
        case .ready where proximityToBottom < 200:
            state = .loading
            
        case .ready, .loading:
            break
        }
    }
}
