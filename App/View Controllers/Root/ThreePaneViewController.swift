//  ThreePaneViewController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import CoreData
import UIKit

/// A three-pane view controller manages three children: one for a primary sidebar, one for a middle list, and one for a "detail" area.
@available(iOS 13.0, *)
final class ThreePaneViewController: UIViewController {

    private let managedObjectContext: NSManagedObjectContext

    private lazy var primarySidebar: PrimarySidebarViewController = {
        let primarySidebar = PrimarySidebarViewController(managedObjectContext: managedObjectContext)
        primarySidebar.delegate = self
        return primarySidebar
    }()

    private lazy var middleListNav: UINavigationController = NavigationController()

    private lazy var detailNav: UINavigationController = NavigationController()

    private var middleNavWidth: NSLayoutConstraint?
    private var primarySidebarWidth: NSLayoutConstraint?

    private lazy var allForums: ForumListViewController = {
        let allForums = ForumListViewController(managedObjectContext: managedObjectContext)
        allForums.title = NSLocalizedString("forums-list.title", comment: "")
        return allForums
    }()

    private lazy var bookmarkedThreads: BookmarksTableViewController = {
        return BookmarksTableViewController(managedObjectContext: managedObjectContext)
    }()

    private lazy var lepersColony: RapSheetViewController = {
        return RapSheetViewController(user: nil)
    }()

    private lazy var privateMessages: MessageListViewController = {
        return MessageListViewController(managedObjectContext: managedObjectContext)
    }()

    init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init(nibName: nil, bundle: nil)

        addChild(primarySidebar)
        addChild(middleListNav)
        addChild(detailNav)
    }

    // MARK: View lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(primarySidebar.view, constrainEdges: [.top, .left, .bottom])
        view.addSubview(middleListNav.view, constrainEdges: [.top, .bottom])
        view.addSubview(detailNav.view, constrainEdges: [.top, .right, .bottom])

        primarySidebarWidth = primarySidebar.view.widthAnchor.constraint(equalToConstant: primarySidebar.preferredContentSize.width)
        primarySidebarWidth?.isActive = true

        middleNavWidth = middleListNav.view.widthAnchor.constraint(equalToConstant: 375)
        middleNavWidth?.isActive = true

        NSLayoutConstraint.activate([
            middleListNav.view.leadingAnchor.constraint(equalTo: primarySidebar.view.trailingAnchor),
            detailNav.view.leadingAnchor.constraint(equalTo: middleListNav.view.trailingAnchor),
        ])

        update()
    }

    private func update() {
        let targetMiddleList: UIViewController
        switch primarySidebar.selectedItem {
        case .allForums:
            targetMiddleList = allForums

        case .bookmarkedThreads:
            targetMiddleList = bookmarkedThreads

        case .favoriteForum(let forumID, _):
            if
                let threadList = middleListNav.viewControllers.first as? ThreadsTableViewController,
                threadList.forum.forumID == forumID
            {
                targetMiddleList = threadList
            } else {
                let key = ForumKey(forumID: forumID)
                let forum = Forum.objectForKey(objectKey: key, inManagedObjectContext: managedObjectContext) as! Forum
                targetMiddleList = ThreadsTableViewController(forum: forum)
            }

        case .lepersColony:
            targetMiddleList = lepersColony

        case .privateMessages:
            targetMiddleList = privateMessages
        }

        if middleListNav.viewControllers.contains(targetMiddleList) {
            middleListNav.popToViewController(targetMiddleList, animated: true)
        } else {
            middleListNav.viewControllers = [targetMiddleList]
        }
    }

    // MARK: Container view controller

    override func preferredContentSizeDidChange(forChildContentContainer child: UIContentContainer) {
        super.preferredContentSizeDidChange(forChildContentContainer: child)

        if child === primarySidebar {
            primarySidebarWidth?.constant = child.preferredContentSize.width
        }
    }

    override func showDetailViewController(_ vc: UIViewController, sender: Any?) {
        detailNav.viewControllers = [vc]
    }

    // MARK: State preservation and restoration

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        coder.encode(children, forKey: StateKey.children)
    }

    private enum StateKey {
        static let children = "children"
    }

    // MARK: Gunk

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Primary sidebar

@available(iOS 13.0, *)
extension ThreePaneViewController: PrimarySidebarViewControllerDelegate {
    func didSelect(_ item: PrimarySidebarViewController.Item, in viewController: PrimarySidebarViewController) {
        update()
    }
}
