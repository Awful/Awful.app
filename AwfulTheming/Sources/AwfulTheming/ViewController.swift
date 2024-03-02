//  ViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Logger
import PullToRefresh
import SwiftUI
import UIKit
import WebKit

private let Log = Logger.get()

public protocol Themeable {

    /// The current theme.
    var theme: Theme { get }

    /// Called whenever `theme` changes.
    func themeDidChange()
}

private func commonInit(_ vc: UIViewController) {
    vc.navigationItem.backBarButtonItem = UIBarButtonItem(title: vc.title, style: .plain, target: nil, action: nil)
}

/**
    A thin customization of UIViewController that extends Theme support.
 
    Instances call `themeDidChange()` after loading their view. `ViewController`'s implementation of `themeDidChange()` sets the view background color and updates the scroll view's indicator (if appropriate).
 */
open class ViewController: UIViewController, Themeable {
    public override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        commonInit(self)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit(self)
    }
    
    /// The theme to use for the view controller. Defaults to `Theme.currentTheme`.
    open var theme: Theme {
        return Theme.defaultTheme()
    }
    
    /// Whether the view controller is currently visible (i.e. has received `viewDidAppear()` without having subsequently received `viewDidDisappear()`).
    public private(set) var visible = false

    // MARK: View lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        themeDidChange()
    }
    
    open func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]
        
        let scrollView: UIScrollView? = {
            var candidates = view.subviews + [view!]
            while let candidate = candidates.popLast() {
                if let scrollView = candidate as? UIScrollView {
                    return scrollView
                } else if candidate.responds(to: Selector(("scrollView"))),
                          let scrollView = candidate.value(forKey: "scrollView") as? UIScrollView
                {
                    return scrollView
                }
            }
            return nil
        }()
        scrollView?.indicatorStyle = theme.scrollIndicatorStyle
    }
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        visible = true
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        visible = false
    }
}

open class HostingController<Content: View>: UIHostingController<Content>, Themeable {

    /**
     The theme to use for the view controller (not necessarily the hosted view; in SwiftUI, use `@Environment(\.theme)`). Defaults to `Theme.defaultTheme()`.
     */
    open var theme: Theme {
        Theme.defaultTheme()
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        themeDidChange()
    }

    open func themeDidChange() {
        if theme[bool: "showRootTabBarLabel"] == false {
            tabBarItem.imageInsets = UIEdgeInsets(top: 9, left: 0, bottom: -9, right: 0)
            tabBarItem.title = nil
        } else {
            tabBarItem.imageInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            tabBarItem.title = title
        }
    }
}

/**
    A thin customization of UITableViewController that extends Theme support and adds some block-based refreshing abilities.
 
 For load more, please see `LoadMoreFooter`.
 */
open class TableViewController: UITableViewController, Themeable {
    private var viewIsLoading = false
    
    public override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        
        commonInit(self)
    }
    
    public override init(style: UITableView.Style) {
        super.init(style: style)
        
        commonInit(self)
    }
    
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit(self)
    }
    
    deinit {
        if isViewLoaded {
            tableView.removeAllPullToRefresh()
        }
    }
    
    /// The theme to use for the view controller. Defaults to `Theme.currentTheme`.
    open var theme: Theme {
        return Theme.defaultTheme()
    }
    
    /// Whether the view controller is currently visible (i.e. has received `viewDidAppear()` without having subsequently received `viewDidDisappear()`).
    public private(set) var visible = false
    
    /// A block to call when the table is pulled down to refresh. If nil, no refresh control is shown.
    public var pullToRefreshBlock: (() -> Void)? {
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
        
        let niggly = NigglyRefreshLottieView(theme: theme)
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
    
    public func startAnimatingPullToRefresh() {
        guard isViewLoaded else { return }
        tableView.startRefreshing(at: .top)
    }
    
    public func stopAnimatingPullToRefresh() {
        guard isViewLoaded else { return }
        tableView.endRefreshing(at: .top)
    }
    
    open override var refreshControl: UIRefreshControl? {
        get { return super.refreshControl }
        set {
            Log.w("we usually use the custom refresh controller")
            super.refreshControl = newValue
        }
    }
    
    // MARK: View lifecycle
    
    open override func viewDidLoad() {
        viewIsLoading = true
        
        super.viewDidLoad()
        
        if pullToRefreshBlock != nil {
            createRefreshControl()
        }
        
        themeDidChange()
        
        viewIsLoading = false
    }
    
    open func themeDidChange() {
        view.backgroundColor = theme["backgroundColor"]
        
        if let pullToRefreshView {
            pullToRefreshView.backgroundColor = view.backgroundColor

            if let niggly = pullToRefreshView as? NigglyRefreshLottieView {
                niggly.theme = theme
            }
        }
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
    
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        visible = true
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        visible = false
    }
}

/// A thin customization of UICollectionViewController that extends Theme support.
class CollectionViewController: UICollectionViewController, Themeable {
    private var viewIsLoading = false
    
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        
        commonInit(self)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit(self)
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
