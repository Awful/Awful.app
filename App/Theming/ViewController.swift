//  ViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Refresher
import UIKit

extension UIViewController {
    // Called when the view controller's theme, derived or otherwise, changes. Subclass implementations should reload and/or update any views customized by the theme, and should call the superclass implementation.
    func themeDidChange() {
        var dependants: Set<UIViewController> = []
        dependants.unionInPlace(childViewControllers)
        if let presented = presentedViewController {
            dependants.insert(presented)
        }
        if
            respondsToSelector(Selector("viewControllers")),
            let viewControllers = valueForKey("viewControllers") as? [UIViewController]
        {
            dependants.unionInPlace(viewControllers)
        }
        
        for viewController in dependants where viewController.isViewLoaded() {
            viewController.themeDidChange()
        }
    }
}

private func CommonInit(vc: UIViewController) {
    vc.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .Plain, target: nil, action: nil)
}

/**
    A thin customization of UIViewController that extends Theme support.
 
    Instances call `themeDidChange()` after loading their view, and they call `themeDidChange()` on all child view controllers and on the presented view controller.
 */
class ViewController: UIViewController {
    override init(nibName: String?, bundle: NSBundle?) {
        super.init(nibName: nibName, bundle: bundle)
        CommonInit(self)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        CommonInit(self)
    }
    
    /// The theme to use for the view controller. Defaults to `Theme.currentTheme`.
    var theme: Theme {
        return Theme.currentTheme
    }
    
    /// Whether the view controller is currently visible (i.e. has received `viewDidAppear()` without having subsequently received `viewDidDisappear()`).
    private(set) var visible = false
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        themeDidChange()
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.backgroundColor = theme["backgroundColor"]
        
        let scrollView: UIScrollView?
        if let scrollingSelf = view as? UIScrollView {
            scrollView = scrollingSelf
        } else if respondsToSelector(Selector("scrollView")), let scrollingSubview = valueForKey("scrollView") as? UIScrollView {
            scrollView = scrollingSubview
        } else {
            scrollView = nil
        }
        scrollView?.indicatorStyle = theme.scrollIndicatorStyle
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        visible = true
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        visible = false
    }
}

/**
    A thin customization of UITableViewController that extends Theme support and adds some block-based refreshing/load more abilities.
 
    Implements `UIScrollViewDelegate.scrollViewDidScroll(_:)`. If your subclass also implements this method, please call its superclass implementation at some point.
 */
class TableViewController: UITableViewController {
    private var viewIsLoading = false
    
    override init(nibName: String?, bundle: NSBundle?) {
        super.init(nibName: nibName, bundle: bundle)
        
        CommonInit(self)
    }
    
    override init(style: UITableViewStyle) {
        super.init(style: style)
        
        CommonInit(self)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        CommonInit(self)
    }
    
    /// The theme to use for the view controller. Defaults to `Theme.currentTheme`.
    var theme: Theme {
        return Theme.currentTheme
    }
    
    /// Whether the view controller is currently visible (i.e. has received `viewDidAppear()` without having subsequently received `viewDidDisappear()`).
    private(set) var visible = false
    
    /// A block to call when the table is pulled down to refresh. If nil, no refresh control is shown.
    var pullToRefreshBlock: (() -> Void)? {
        didSet {
            if pullToRefreshBlock != nil {
                createRefreshControl()
            } else {
                if isViewLoaded() {
                    tableView.pullToRefreshView?.removeFromSuperview()
                }
            }
        }
    }
    
    private func createRefreshControl() {
        guard tableView.pullToRefreshView == nil else { return }
        let niggly = NigglyRefreshView()
        niggly.autoresizingMask = .FlexibleWidth
        tableView.addPullToRefreshWithAction({ [unowned self] in
            self.pullToRefreshBlock?()
            }, withAnimator: niggly)
        tableView.pullToRefreshView?.tintColor = theme["listSeparatorColor"]
    }
    
    func stopAnimatingPullToRefresh() {
        guard isViewLoaded() else { return }
        tableView.stopPullToRefresh()
    }
    
    override var refreshControl: UIRefreshControl? {
        // These were here to help migrate away from UIRefreshControl. Might as well leave them in to make sure we don't accidentally try something.
        get { fatalError("use pullToRefreshView") }
        set { fatalError("use pullToRefreshView") }
    }
    
    /// A block to call when the table is pulled up to load more content. If nil, no load more control is shown.
    var scrollToLoadMoreBlock: (() -> Void)? {
        didSet {
            if scrollToLoadMoreBlock != nil {
                createInfiniteScroll()
            } else {
                infiniteScrollController = nil
            }
        }
    }
    
    private func createInfiniteScroll() {
        guard let block = scrollToLoadMoreBlock else { return }
        infiniteScrollController = InfiniteTableController(tableView: tableView, loadMore: block)
        infiniteScrollController?.spinnerColor = theme["listSeparatorColor"]
    }
    
    /// Returns the current infinite scroll controller, or nil if scrollToLoadMoreBlock is nil.
    private(set) var infiniteScrollController: InfiniteTableController?
    
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        infiniteScrollController?.scrollViewDidScroll(scrollView)
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        viewIsLoading = true
        
        super.viewDidLoad()
        
        if let _ = pullToRefreshBlock {
            createRefreshControl()
        }
        if let _ = scrollToLoadMoreBlock {
            createInfiniteScroll()
        }
        
        themeDidChange()
        
        viewIsLoading = false
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.backgroundColor = theme["backgroundColor"]
        
        tableView.pullToRefreshView?.tintColor = theme["listSeparatorColor"]
        infiniteScrollController?.spinnerColor = theme["listSeparatorColor"]
        
        tableView.indicatorStyle = theme.scrollIndicatorStyle
        tableView.separatorColor = theme["listSeparatorColor"]
        
        if !viewIsLoading {
            tableView.reloadData()
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        visible = true
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        visible = false
    }
}

/// A thin customization of UICollectionViewController that extends Theme support.
class CollectionViewController: UICollectionViewController {
    private var viewIsLoading = false
    
    override init(nibName: String?, bundle: NSBundle?) {
        super.init(nibName: nibName, bundle: bundle)
        
        CommonInit(self)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        CommonInit(self)
    }
    
    /// The theme to use for the view controller. Defaults to `Theme.currentTheme`.
    var theme: Theme {
        return Theme.currentTheme
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        viewIsLoading = true
        
        super.viewDidLoad()
        
        themeDidChange()
        
        viewIsLoading = false
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.backgroundColor = theme["backgroundColor"]
        
        collectionView?.indicatorStyle = theme.scrollIndicatorStyle
        
        if !viewIsLoading {
            collectionView?.reloadData()
        }
    }
}
