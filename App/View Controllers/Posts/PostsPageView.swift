//  PostsPageView.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

/// Manages a posts page's render view, top bar, and toolbar.
final class PostsPageView: UIView {

    var loadingView: UIView? {
        get { return loadingViewContainer.subviews.first }
        set {
            loadingViewContainer.subviews.forEach { $0.removeFromSuperview() }
            if let newValue = newValue {
                loadingViewContainer.addSubview(newValue, constrainEdges: .all)
            }
            loadingViewContainer.isHidden = newValue == nil
        }
    }

    private lazy var loadingViewContainer = LoadingViewContainer()

    /// Trivial subclass to identify the view when debugging.
    final class LoadingViewContainer: UIView {}

    let renderView = RenderView()

    private let toolbar = Toolbar()

    var toolbarItems: [UIBarButtonItem] {
        get { return toolbar.items ?? [] }
        set { toolbar.items = newValue }
    }

    let topBar = PostsPageTopBar()
    
    override init(frame: CGRect) {
        super.init(frame: frame)

        addSubview(renderView, constrainEdges: [.top, .bottom, .left, .right])
        addSubview(topBar, constrainEdges: [.left, .right])
        addSubview(loadingViewContainer, constrainEdges: .all)
        addSubview(toolbar, constrainEdges: [.left, .right])

        let topBarHeight = topBar.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        topBarHeight.priority = .init(rawValue: 500)

        // See commentary in `PostsPageViewController.viewDidLoad()` about our layout strategy here. tl;dr layout margins are the highest-level approach available on all versions of iOS that Awful supports, so we'll use them exclusively to represent the safe area.
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            topBarHeight,
            layoutMarginsGuide.bottomAnchor.constraint(equalTo: toolbar.bottomAnchor)])
    }

    override func layoutSubviews() {

        // Let Auto Layout do its thing first, so we can use bar frames to figure out content insets.
        super.layoutSubviews()

        /*
         I'm assuming `layoutSubviews()` will get called (among other times) whenever `layoutMarginsDidChange()` gets called, so there's no point overriding `layoutMarginsDidChange()` to do the same work we're doing here. But I haven't yet convinced myself that this is how things work.

         See commentary in `PostsPageViewController.viewDidLoad()` about our layout strategy here. tl;dr layout margins are the highest-level approach available on all versions of iOS that Awful supports, so we'll use them exclusively to represent the safe area.
         */

        let scrollView = renderView.scrollView
        let contentInset = UIEdgeInsets(top: topBar.frame.maxY, left: 0, bottom: bounds.maxY - toolbar.frame.minY, right: 0)
        scrollView.contentInset = contentInset

        if #available(iOS 12.0, *) {
            // I'm not sure if this is a bug or if I'm misunderstanding something, but on iOS 12 it seems that the indicator insets have already taken the safe area into account? At least, that's what setting the indicator insets to zero seems to suggest. In that case, we'll remove our adjustment for the safe area (which we're representing using layout margins).
            var indicatorInsets = contentInset
            indicatorInsets.top -= layoutMargins.top
            indicatorInsets.bottom -= layoutMargins.bottom
            scrollView.scrollIndicatorInsets = indicatorInsets
        } else {
            scrollView.scrollIndicatorInsets = contentInset
        }
    }

    func themeDidChange(_ theme: Theme){
        renderView.scrollView.indicatorStyle = theme.scrollIndicatorStyle
        renderView.setThemeStylesheet(theme["postsViewCSS"] ?? "")

        toolbar.barTintColor = theme["toolbarTintColor"]
        toolbar.tintColor = theme["toolbarTextColor"]
        toolbar.topBorderColor = theme["bottomBarTopBorderColor"]
        toolbar.isTranslucent = theme[bool: "tabBarIsTranslucent"] ?? true

        topBar.themeDidChange(theme)
    }

    // MARK: Gunk
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
