//  ViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PullToRefresh
import UIKit

extension UIViewController {
    // Called when the view controller's theme, derived or otherwise, changes. Subclass implementations should reload and/or update any views customized by the theme, and should call the superclass implementation.
    func themeDidChange() {
        var dependants: Set<UIViewController> = []
        dependants.formUnion(Set(childViewControllers))
        if let presented = presentedViewController {
            dependants.insert(presented)
        }
        if
            responds(to: #selector(getter: UINavigationController.viewControllers)),
            let viewControllers = value(forKey: "viewControllers") as? [UIViewController]
        {
            dependants.formUnion(Set(viewControllers))
        }
        
        for viewController in dependants where viewController.isViewLoaded {
            viewController.themeDidChange()
        }
    }
}

private func CommonInit(_ vc: UIViewController) {
    vc.navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
}

/**
    A thin customization of UIViewController that extends Theme support.
 
    Instances call `themeDidChange()` after loading their view, and they call `themeDidChange()` on all child view controllers and on the presented view controller.
 */
class ViewController: UIViewController {
    override init(nibName: String?, bundle: Bundle?) {
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
    fileprivate(set) var visible = false
    
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
        } else if responds(to: #selector(getter: UIWebView.scrollView)), let scrollingSubview = value(forKey: "scrollView") as? UIScrollView {
            scrollView = scrollingSubview
        } else {
            scrollView = nil
        }
        scrollView?.indicatorStyle = theme.scrollIndicatorStyle
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        visible = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        visible = false
    }
}

/**
    A thin customization of UITableViewController that extends Theme support and adds some block-based refreshing/load more abilities.
 
    Implements `UITableViewDelegate.tableView(_:willDisplayCell:forRowAtIndexPath:)`. If your subclass also implements this method, please call its superclass implementation at some point.
 */
class TableViewController: UITableViewController {
    fileprivate var viewIsLoading = false
    
    override init(nibName: String?, bundle: Bundle?) {
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
    
    deinit {
        if isViewLoaded, let pullToRefresh = tableView.topPullToRefresh {
            tableView.removePullToRefresh(pullToRefresh)
        }
    }
    
    /// The theme to use for the view controller. Defaults to `Theme.currentTheme`.
    var theme: Theme {
        return Theme.currentTheme
    }
    
    /// Whether the view controller is currently visible (i.e. has received `viewDidAppear()` without having subsequently received `viewDidDisappear()`).
    fileprivate(set) var visible = false
    
    /// A block to call when the table is pulled down to refresh. If nil, no refresh control is shown.
    var pullToRefreshBlock: (() -> Void)? {
        didSet {
            if pullToRefreshBlock != nil {
                createRefreshControl()
            } else {
                if isViewLoaded, let pullToRefresh = tableView.topPullToRefresh {
                    tableView.removePullToRefresh(pullToRefresh)
                }
            }
        }
    }
    
    fileprivate func createRefreshControl() {
        guard tableView.topPullToRefresh == nil else { return }
        let niggly = NigglyRefreshView()
        niggly.autoresizingMask = .flexibleWidth
        niggly.backgroundColor = view.backgroundColor
        niggly.bounds.size.height += 8
        pullToRefreshView = niggly
        let pullToRefresh = PullToRefresh(refreshView: niggly, animator: niggly, height: niggly.bounds.height, position: .top)
        pullToRefresh.animationDuration = 0.3
        pullToRefresh.initialSpringVelocity = 0
        pullToRefresh.springDamping = 1
        tableView.addPullToRefresh(pullToRefresh, action: { [weak self] in self?.pullToRefreshBlock?() })
    }
    
    fileprivate weak var pullToRefreshView: UIView?
    
    func startAnimatingPullToRefresh() {
        guard isViewLoaded else { return }
        tableView.startRefreshing(at: .top)
    }
    
    func stopAnimatingPullToRefresh() {
        guard isViewLoaded else { return }
        tableView.endRefreshing(at: .top)
    }
    
    override var refreshControl: UIRefreshControl? {
        // These were here to help migrate away from UIRefreshControl. Might as well leave them in to make sure we don't accidentally try something.
        get { fatalError("use pullToRefreshView") }
        set { fatalError("use pullToRefreshView") }
    }
    
    /// A block to call when the table is pulled up to load more content. If nil, no load more control is shown.
    var scrollToLoadMoreBlock: (() -> Void)? {
        didSet {
            if scrollToLoadMoreBlock == nil {
                stopAnimatingInfiniteScroll()
            }
        }
    }
    
    fileprivate enum InfiniteScrollState {
        case ready
        case loadingMore
    }
    fileprivate var infiniteScrollState: InfiniteScrollState = .ready
    
    func stopAnimatingInfiniteScroll() {
        infiniteScrollState = .ready
        
        guard let footer = tableView.tableFooterView else { return }
        tableView.contentInset.bottom -= footer.bounds.height
        tableView.tableFooterView = nil
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        viewIsLoading = true
        
        super.viewDidLoad()
        
        if pullToRefreshBlock != nil {
            createRefreshControl()
        }
        
        themeDidChange()
        
        viewIsLoading = false
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        view.backgroundColor = theme["backgroundColor"]
        
        pullToRefreshView?.backgroundColor = view.backgroundColor
        tableView.tableFooterView?.backgroundColor = view.backgroundColor
        
        tableView.indicatorStyle = theme.scrollIndicatorStyle
        tableView.separatorColor = theme["listSeparatorColor"]
        
        if !viewIsLoading {
            tableView.reloadData()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        visible = true
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        visible = false
    }
    
    // MARK: UITableViewDelegate
    
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard infiniteScrollState == .ready, let block = scrollToLoadMoreBlock else { return }
        guard indexPath.row + 1 == tableView.dataSource?.tableView(tableView, numberOfRowsInSection: indexPath.section) else { return }
        guard tableView.contentSize.height >= tableView.bounds.height else { return }
        
        infiniteScrollState = .loadingMore
        block()
        
        let loadMoreView = NigglyLoadMoreView()
        loadMoreView.sizeToFit()
        loadMoreView.bounds.size.height += 12
        loadMoreView.backgroundColor = tableView.backgroundColor
        tableView.tableFooterView = loadMoreView
        
        tableView.contentInset.bottom += loadMoreView.bounds.height
    }
}

/// A thin customization of UICollectionViewController that extends Theme support.
class CollectionViewController: UICollectionViewController {
    fileprivate var viewIsLoading = false
    
    override init(nibName: String?, bundle: Bundle?) {
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
