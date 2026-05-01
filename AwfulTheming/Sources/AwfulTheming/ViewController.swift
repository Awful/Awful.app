//  ViewController.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import PullToRefresh
import SwiftUI
import UIKit

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
    A thin customization of UICollectionViewController that extends Theme support
    and adds block-based pull-to-refresh.

    For load-more pagination, see `LoadMoreCollectionFooter`.
 */
open class CollectionViewController: UICollectionViewController, Themeable {
    private var viewIsLoading = false

    public override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)

        commonInit(self)
    }

    public override init(collectionViewLayout layout: UICollectionViewLayout) {
        super.init(collectionViewLayout: layout)

        commonInit(self)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)

        commonInit(self)
    }

    deinit {
        if isViewLoaded {
            collectionView.removeAllPullToRefresh()
        }
    }

    /// The theme to use for the view controller. Defaults to `Theme.currentTheme`.
    open var theme: Theme {
        return Theme.defaultTheme()
    }

    /// Whether the view controller is currently visible (i.e. has received
    /// `viewDidAppear()` without having subsequently received `viewDidDisappear()`).
    public private(set) var visible = false

    /// A block to call when the collection is pulled down to refresh. If nil, no refresh control is shown.
    public var pullToRefreshBlock: (() -> Void)? {
        didSet {
            if pullToRefreshBlock != nil {
                createRefreshControl()
            } else {
                if isViewLoaded {
                    collectionView.removePullToRefresh(at: .top)
                }
            }
        }
    }

    private func createRefreshControl() {
        guard collectionView.topPullToRefresh == nil else { return }

        let niggly = NigglyRefreshLottieView(theme: theme)
        let targetSize = CGSize(width: collectionView.bounds.width, height: 0)

        niggly.bounds.size = niggly.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        niggly.autoresizingMask = .flexibleWidth
        niggly.backgroundColor = view.backgroundColor

        pullToRefreshView = niggly

        let animator = NigglyRefreshLottieView.RefreshAnimator(view: niggly)

        let pullToRefresh = PullToRefresh(refreshView: niggly, animator: animator, height: niggly.bounds.height, position: .top)
        pullToRefresh.animationDuration = 0.3
        pullToRefresh.initialSpringVelocity = 0
        pullToRefresh.springDamping = 1
        collectionView.addPullToRefresh(pullToRefresh, action: { [weak self] in
            self?.pullToRefreshBlock?()
        })
    }

    private weak var pullToRefreshView: UIView?

    public func startAnimatingPullToRefresh() {
        guard isViewLoaded else { return }
        collectionView.startRefreshing(at: .top)
    }

    public func stopAnimatingPullToRefresh() {
        guard isViewLoaded else { return }
        collectionView.endRefreshing(at: .top)
    }

    // MARK: View lifecycle

    open override func viewDidLoad() {
        viewIsLoading = true

        super.viewDidLoad()

        // iOS 26 sidebar contexts apply default 8pt directional layout margins
        // on the collection view. Combined with the ~13pt section content inset
        // baked into UICollectionLayoutListConfiguration, this leaves a visible
        // gap on the column's leading edge. Zero the margins here; subclasses
        // that build their layout via `makeListLayout(using:)` get the matching
        // section.contentInsets bypass automatically.
        collectionView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        collectionView.preservesSuperviewLayoutMargins = false

        if pullToRefreshBlock != nil {
            createRefreshControl()
        }

        themeDidChange()

        viewIsLoading = false
    }

    /// Build a list-style compositional layout that bypasses iOS 26's automatic
    /// ~13pt section content inset on sidebar contexts. Use this in place of
    /// `UICollectionViewCompositionalLayout.list(using:)` for every list-based
    /// collection view in the app — it is the only thing that lets cells span
    /// the column's full width on iPad sidebars and Designed-for-iPad-on-Mac.
    ///
    /// - Parameter pinSectionHeaders: If `false`, section header supplementary
    ///   items scroll away with the content instead of sticking to the top.
    public static func makeListLayout(
        using listConfig: UICollectionLayoutListConfiguration,
        pinSectionHeaders: Bool = true
    ) -> UICollectionViewCompositionalLayout {
        let layoutConfig = UICollectionViewCompositionalLayoutConfiguration()
        layoutConfig.contentInsetsReference = .none
        return UICollectionViewCompositionalLayout(
            sectionProvider: { _, layoutEnvironment in
                let section = NSCollectionLayoutSection.list(using: listConfig, layoutEnvironment: layoutEnvironment)
                section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
                if !pinSectionHeaders {
                    for item in section.boundarySupplementaryItems where item.elementKind == UICollectionView.elementKindSectionHeader {
                        item.pinToVisibleBounds = false
                    }
                }
                return section
            },
            configuration: layoutConfig
        )
    }

    open func themeDidChange() {
        let bg = theme[uicolor: "backgroundColor"]
        view.backgroundColor = bg
        collectionView.backgroundColor = bg

        if let pullToRefreshView {
            pullToRefreshView.backgroundColor = bg

            if let niggly = pullToRefreshView as? NigglyRefreshLottieView {
                niggly.theme = theme
            }
        }

        collectionView.indicatorStyle = theme.scrollIndicatorStyle

        if !viewIsLoading {
            collectionView.reloadData()
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

    // MARK: Scroll view delegate for iOS 26 dynamic color adaptation

    open override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update navigation bar tint for iOS 26+ dynamic colors
        if #available(iOS 26.0, *) {
            // Skip programmatic offset changes (e.g. pull-to-refresh) that can
            // briefly appear "fully scrolled" and flip the nav bar to transparent.
            guard scrollView.isDragging || scrollView.isDecelerating else {
                return
            }

            let topInset = scrollView.adjustedContentInset.top
            let currentOffset = scrollView.contentOffset.y
            let topPosition = -topInset

            let transitionDistance: CGFloat = 30.0

            let progress: CGFloat
            if currentOffset <= topPosition {
                progress = 0.0
            } else if currentOffset >= topPosition + transitionDistance {
                progress = 1.0
            } else {
                let distanceFromTop = currentOffset - topPosition
                progress = distanceFromTop / transitionDistance
            }

            if let navController = navigationController,
               navController.responds(to: Selector(("updateNavigationBarTintForScrollProgress:"))) {
                navController.perform(Selector(("updateNavigationBarTintForScrollProgress:")), with: NSNumber(value: Float(progress)))
            }
        }
    }
}

/**
    A `UIViewController` subclass that hosts a `UICollectionView` as a child of
    its `view` (rather than `view == collectionView` as in `UICollectionViewController`).
    Use this when you need sibling subviews next to the collection view — most
    commonly a search bar pinned above it. A search bar in a UICollectionReusableView
    supplementary view loses first responder on every `apply()` because UIKit's
    `_resignOrRebaseFirstResponderViewWithIndexPathMapping` doesn't protect
    supplementary views the way it protects cells; hosting the search bar outside
    the collection view sidesteps that lifecycle entirely.

    Provides the same theming, pull-to-refresh, visibility tracking, tab-bar-item
    label management, and iOS 26 scroll-progress hook as `CollectionViewController`.
 */
open class HostedCollectionViewController: UIViewController, Themeable {
    private var viewIsLoading = false

    public let collectionView: UICollectionView

    public init(collectionViewLayout layout: UICollectionViewLayout) {
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
        commonInit(self)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if isViewLoaded {
            collectionView.removeAllPullToRefresh()
        }
    }

    /// The theme to use for the view controller. Defaults to `Theme.currentTheme`.
    open var theme: Theme {
        return Theme.defaultTheme()
    }

    /// Whether the view controller is currently visible.
    public private(set) var visible = false

    /// A block to call when the collection is pulled down to refresh. If nil, no refresh control is shown.
    public var pullToRefreshBlock: (() -> Void)? {
        didSet {
            if pullToRefreshBlock != nil {
                createRefreshControl()
            } else {
                if isViewLoaded {
                    collectionView.removePullToRefresh(at: .top)
                }
            }
        }
    }

    private func createRefreshControl() {
        guard isViewLoaded, collectionView.topPullToRefresh == nil else { return }

        let niggly = NigglyRefreshLottieView(theme: theme)
        let targetSize = CGSize(width: collectionView.bounds.width, height: 0)

        niggly.bounds.size = niggly.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        niggly.autoresizingMask = .flexibleWidth
        niggly.backgroundColor = view.backgroundColor

        pullToRefreshView = niggly

        let animator = NigglyRefreshLottieView.RefreshAnimator(view: niggly)

        let pullToRefresh = PullToRefresh(refreshView: niggly, animator: animator, height: niggly.bounds.height, position: .top)
        pullToRefresh.animationDuration = 0.3
        pullToRefresh.initialSpringVelocity = 0
        pullToRefresh.springDamping = 1
        collectionView.addPullToRefresh(pullToRefresh, action: { [weak self] in
            self?.pullToRefreshBlock?()
        })
    }

    private weak var pullToRefreshView: UIView?

    public func startAnimatingPullToRefresh() {
        guard isViewLoaded else { return }
        collectionView.startRefreshing(at: .top)
    }

    public func stopAnimatingPullToRefresh() {
        guard isViewLoaded else { return }
        collectionView.endRefreshing(at: .top)
    }

    // MARK: View lifecycle

    open override func loadView() {
        let view = UIView()
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        self.view = view
    }

    open override func viewDidLoad() {
        viewIsLoading = true

        super.viewDidLoad()

        // iOS 26 sidebar contexts apply default 8pt directional layout margins,
        // matching the fix in CollectionViewController. See its comment for why.
        collectionView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        collectionView.preservesSuperviewLayoutMargins = false

        // Default delegate is the VC. Subclasses using a delegate multiplexer
        // will overwrite this when their lazy multiplexer initializes.
        collectionView.delegate = self

        if pullToRefreshBlock != nil {
            createRefreshControl()
        }

        themeDidChange()

        viewIsLoading = false
    }

    open func themeDidChange() {
        let bg = theme[uicolor: "backgroundColor"]
        view.backgroundColor = bg
        collectionView.backgroundColor = bg

        if let pullToRefreshView {
            pullToRefreshView.backgroundColor = bg

            if let niggly = pullToRefreshView as? NigglyRefreshLottieView {
                niggly.theme = theme
            }
        }

        collectionView.indicatorStyle = theme.scrollIndicatorStyle

        if !viewIsLoading {
            collectionView.reloadData()
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

extension HostedCollectionViewController: UICollectionViewDelegate {
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Update navigation bar tint for iOS 26+ dynamic colors. Same logic as
        // CollectionViewController.
        if #available(iOS 26.0, *) {
            guard scrollView.isDragging || scrollView.isDecelerating else { return }

            let topInset = scrollView.adjustedContentInset.top
            let currentOffset = scrollView.contentOffset.y
            let topPosition = -topInset

            let transitionDistance: CGFloat = 30.0

            let progress: CGFloat
            if currentOffset <= topPosition {
                progress = 0.0
            } else if currentOffset >= topPosition + transitionDistance {
                progress = 1.0
            } else {
                let distanceFromTop = currentOffset - topPosition
                progress = distanceFromTop / transitionDistance
            }

            if let navController = navigationController,
               navController.responds(to: Selector(("updateNavigationBarTintForScrollProgress:"))) {
                navController.perform(Selector(("updateNavigationBarTintForScrollProgress:")), with: NSNumber(value: Float(progress)))
            }
        }
    }
}
