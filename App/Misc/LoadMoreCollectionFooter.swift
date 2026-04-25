//  LoadMoreCollectionFooter.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import ScrollViewDelegateMultiplexer
import UIKit

/// Collection-view peer of `LoadMoreFooter`. Pins a spinner to the collection
/// view's `contentLayoutGuide.bottomAnchor` and reserves `contentInset.bottom`
/// while loading so the spinner is visible past the last cell.
final class LoadMoreCollectionFooter: NSObject {

    private let loadMore: (LoadMoreCollectionFooter) -> Void
    private let collectionView: UICollectionView

    private enum State {
        case ready, loading
    }

    private var state: State = .ready {
        didSet {
            switch (oldValue, state) {
            case (.ready, .loading):
                themeDidChange()
                attachRefreshView()
                refreshView.startAnimating()

                loadMore(self)

            case (.loading, .ready):
                detachRefreshView()
                refreshView.stopAnimating()

            case (.ready, _), (.loading, _):
                break
            }
        }
    }

    private lazy var refreshView: NigglyRefreshView = {
        let view = NigglyRefreshView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var pinningConstraints: [NSLayoutConstraint] = []

    init(collectionView: UICollectionView, multiplexer: ScrollViewDelegateMultiplexer, loadMore: @escaping (LoadMoreCollectionFooter) -> Void) {
        self.loadMore = loadMore
        self.collectionView = collectionView
        super.init()

        multiplexer.addDelegate(self)
    }

    deinit {
        removeFromCollectionView()
    }

    func didFinish() {
        switch state {
        case .loading:
            state = .ready

        case .ready:
            break
        }
    }

    func removeFromCollectionView() {
        detachRefreshView()
    }

    func themeDidChange() {
        refreshView.backgroundColor = collectionView.backgroundColor
    }

    private func attachRefreshView() {
        let height = refreshView.intrinsicContentSize.height

        if refreshView.superview !== collectionView {
            collectionView.addSubview(refreshView)
        }

        NSLayoutConstraint.deactivate(pinningConstraints)
        pinningConstraints = [
            refreshView.leadingAnchor.constraint(equalTo: collectionView.contentLayoutGuide.leadingAnchor),
            refreshView.trailingAnchor.constraint(equalTo: collectionView.contentLayoutGuide.trailingAnchor),
            refreshView.topAnchor.constraint(equalTo: collectionView.contentLayoutGuide.bottomAnchor),
            refreshView.heightAnchor.constraint(equalToConstant: height),
        ]
        NSLayoutConstraint.activate(pinningConstraints)

        // Reserve room past the last cell so the pinned spinner is visible.
        collectionView.contentInset.bottom = height
    }

    private func detachRefreshView() {
        NSLayoutConstraint.deactivate(pinningConstraints)
        pinningConstraints = []
        refreshView.removeFromSuperview()
        collectionView.contentInset.bottom = 0
    }

    // MARK: Gunk

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension LoadMoreCollectionFooter: UICollectionViewDelegate {
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {

        assert(scrollView === collectionView)

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
