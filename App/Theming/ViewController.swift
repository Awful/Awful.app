//  ViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PullToRefresh
import UIKit
import WebKit

private let Log = Logger.get()

protocol Themeable {

    /// The current theme.
    var theme: Theme { get }

    /// Called whenever `theme` changes.
    func themeDidChange()
}

private func CommonInit(_ vc: UIViewController) {
    vc.navigationItem.backBarButtonItem = UIBarButtonItem(title: vc.title, style: .plain, target: nil, action: nil)
}

/**
    A thin customization of UIViewController that extends Theme support.
 
    Instances call `themeDidChange()` after loading their view. `ViewController`'s implementation of `themeDidChange()` sets the view background color and updates the scroll view's indicator (if appropriate).
 */
class ViewController: UIViewController, Themeable {
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
        return Theme.defaultTheme()
    }
    
    /// Whether the view controller is currently visible (i.e. has received `viewDidAppear()` without having subsequently received `viewDidDisappear()`).
    private(set) var visible = false
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        themeDidChange()
    }
    
    func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]
        
        let scrollView: UIScrollView? = {
            var candidates = view.subviews + [view]
            while let candidate = candidates.popLast() {
                switch candidate {
                case let rv as RenderView: return rv.scrollView
                case let sv as UIScrollView: return sv
                case let wv as WKWebView: return wv.scrollView
                default: continue
                }
            }
            return nil
        }()
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
    A thin customization of UITableViewController that extends Theme support and adds some block-based refreshing abilities.
 
 For load more, please see `LoadMoreFooter`.
 */
class TableViewController: UITableViewController, Themeable {
    private var viewIsLoading = false
    
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        
        CommonInit(self)
    }
    
    override init(style: UITableView.Style) {
        super.init(style: style)
        
        CommonInit(self)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        CommonInit(self)
    }
    
    deinit {
        if isViewLoaded {
            tableView.removeAllPullToRefresh()
        }
    }
    
    /// The theme to use for the view controller. Defaults to `Theme.currentTheme`.
    var theme: Theme {
        return Theme.defaultTheme()
    }
    
    /// Whether the view controller is currently visible (i.e. has received `viewDidAppear()` without having subsequently received `viewDidDisappear()`).
    private(set) var visible = false
    
    /// A block to call when the table is pulled down to refresh. If nil, no refresh control is shown.
    var pullToRefreshBlock: (() -> Void)? {
        didSet {
            if pullToRefreshBlock != nil {
                createRefreshControl()
            } else {
                if isViewLoaded {
                    tableView.removePullToRefresh(at: .top)
                }
            }
        }
    }
    
    private func createRefreshControl() {
        guard tableView.topPullToRefresh == nil else { return }
        
        let niggly = NigglyRefreshLottieView()
        let targetSize = CGSize(width: tableView.bounds.width, height: 0)
       
        niggly.bounds.size = niggly.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        niggly.autoresizingMask = .flexibleWidth
        niggly.backgroundColor = view.backgroundColor
        
        pullToRefreshView = niggly
        
        let animator = NigglyRefreshLottieView.RefreshAnimator(view: niggly)
        
        let pullToRefresh = PullToRefresh(refreshView: niggly, animator: animator, height: niggly.bounds.height, position: .top)
        pullToRefresh.animationDuration = 0.3
        pullToRefresh.initialSpringVelocity = 0
        pullToRefresh.springDamping = 1
        tableView.addPullToRefresh(pullToRefresh, action: { [weak self] in
            self?.pullToRefreshBlock?()
        })
    }
    
    private weak var pullToRefreshView: UIView?
    
    func startAnimatingPullToRefresh() {
        guard isViewLoaded else { return }
        tableView.startRefreshing(at: .top)
    }
    
    func stopAnimatingPullToRefresh() {
        guard isViewLoaded else { return }
        tableView.endRefreshing(at: .top)
    }
    
    override var refreshControl: UIRefreshControl? {
        get { return super.refreshControl }
        set {
            Log.w("we usually use the custom refresh controller")
            super.refreshControl = newValue
        }
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
    
    func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]
        
        pullToRefreshView?.backgroundColor = view.backgroundColor
        tableView.tableFooterView?.backgroundColor = view.backgroundColor
        
        tableView.indicatorStyle = theme.scrollIndicatorStyle
        tableView.separatorColor = theme["listSeparatorColor"]
        
        if !viewIsLoading {
            tableView.reloadData()
        }
        
        if theme[bool: "showRootTabBarLabel"] == false {
            tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 0, bottom: -9, right: 0)
            tabBarItem.title = nil
        } else {
            tabBarItem.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            tabBarItem.title = title
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
}

/// A thin customization of UICollectionViewController that extends Theme support.
class CollectionViewController: UICollectionViewController, Themeable {
    private var viewIsLoading = false
    
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
        return Theme.defaultTheme()
    }
    
    // MARK: View lifecycle
    
    override func viewDidLoad() {
        viewIsLoading = true
        
        super.viewDidLoad()
        
        themeDidChange()
        
        viewIsLoading = false
    }
    
    func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]
        
        collectionView?.indicatorStyle = theme.scrollIndicatorStyle
        
        if !viewIsLoading {
            collectionView?.reloadData()
        }
    }
}
