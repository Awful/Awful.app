//  IconActionItem.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class IconActionItem: NSObject {
    var title: String
    let icon: UIImage
    let themeKey: String
    let block: () -> Void
    
    @nonobjc convenience init(_ action: IconAction, block: () -> Void) {
        guard let icon = UIImage(named: action.iconName) else { fatalError("missing image named \(action.iconName)") }
        self.init(title: action.title, icon: icon, themeKey: action.themeKey, block: block)
    }
    
    static func itemWithAction(action: IconAction, block: () -> Void) -> IconActionItem {
        return self.init(action, block: block)
    }
    
    private init(title: String, icon: UIImage, themeKey: String, block: () -> Void) {
        self.title = title
        self.icon = icon
        self.themeKey = themeKey
        self.block = block
        super.init()
    }
}

@objc enum IconAction: Int {
    case AddBookmark
    case CopyURL
    case EditPost
    case JumpToFirstPage
    case JumpToLastPage
    case MarkAsUnread
    case MarkReadUpToHere
    case QuotePost
    case RapSheet
    case RemoveBookmark
    case ReportPost
    case SendPrivateMessage
    case ShowInThread
    case SingleUsersPosts
    case UserProfile
    case Vote
    
    private var title: String {
        switch self {
        case .AddBookmark: return "Bookmark"
        case .CopyURL: return "Link"
        case .EditPost: return "Edit"
        case .JumpToFirstPage: return "First Page"
        case .JumpToLastPage: return "Last Page"
        case .MarkAsUnread: return "Mark Unread"
        case .MarkReadUpToHere: return "Mark Read"
        case .QuotePost: return "Quote"
        case .RapSheet: return "Rap Sheet"
        case .ReportPost: return "Report"
        case .RemoveBookmark: return "Unmark"
        case .SendPrivateMessage: return "PM"
        case .ShowInThread: return "All Posts"
        case .SingleUsersPosts: return "Their Posts"
        case .UserProfile: return "Profile"
        case .Vote: return "Vote"
        }
    }
    
    private var iconName: String {
        switch self {
        case .AddBookmark: return "add-bookmark"
        case .CopyURL: return "copy-url"
        case .EditPost: return "edit-post"
        case .JumpToFirstPage: return "jump-to-first-page"
        case .JumpToLastPage: return "jump-to-last-page"
        case .MarkAsUnread: return "mark-as-unread"
        case .MarkReadUpToHere: return "mark-read-up-to-here"
        case .QuotePost: return "quote-post"
        case .RapSheet: return "rap-sheet"
        case .ReportPost: return "rap-sheet"
        case .RemoveBookmark: return "remove-bookmark"
        case .SendPrivateMessage: return "send-private-message"
        case .ShowInThread: return "view-in-thread"
        case .SingleUsersPosts: return "single-users-posts"
        case .UserProfile: return "user-profile"
        case .Vote: return "vote"
        }
    }
    
    private var themeKey: String {
        switch self {
        case .AddBookmark: return "addBookmarkIconColor"
        case .CopyURL: return "copyURLIconColor"
        case .EditPost: return "editPostIconColor"
        case .JumpToFirstPage: return "jumpToFirstPageIconColor"
        case .JumpToLastPage: return "jumpToLastPageIconColor"
        case .MarkAsUnread: return "markUnreadIconColor"
        case .MarkReadUpToHere: return "markReadUpToHereIconColor"
        case .QuotePost: return "quoteIconColor"
        case .RapSheet: return "rapSheetIconColor"
        case .ReportPost: return "rapSheetIconColor"
        case .RemoveBookmark: return "removeBookmarkIconColor"
        case .SendPrivateMessage: return "sendPMIconColor"
        case .ShowInThread: return "showInThreadIconColor"
        case .SingleUsersPosts: return "singleUserIconColor"
        case .UserProfile: return "profileIconColor"
        case .Vote: return "voteIconColor"
        }
    }
}
