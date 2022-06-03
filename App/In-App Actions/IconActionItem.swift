//  IconActionItem.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

final class IconActionItem: NSObject {
    var title: String
    let icon: UIImage
    let themeKey: String
    let block: () -> Void
    
    @nonobjc convenience init(_ action: IconAction, title: String? = nil, block: @escaping () -> Void) {
        guard let icon = UIImage(named: action.iconName) else { fatalError("missing image named \(action.iconName)") }
        self.init(title: title ?? action.title, icon: icon, themeKey: action.themeKey, block: block)
    }
    
    static func itemWithAction(_ action: IconAction, block: @escaping () -> Void) -> IconActionItem {
        return self.init(action, block: block)
    }
    
    fileprivate init(title: String, icon: UIImage, themeKey: String, block: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.themeKey = themeKey
        self.block = block
        super.init()
    }
}

@objc enum IconAction: Int {
    case addBookmark
    case copyURL
    case copyTitle
    case editPost
    case ignoreUser
    case jumpToFirstPage
    case jumpToLastPage
    case markAsUnread
    case markReadUpToHere
    case ownPosts
    case quotePost
    case copyPost
    case rapSheet
    case removeBookmark
    case reportPost
    case sendPrivateMessage
    case showInThread
    case singleUsersPosts
    case unignoreUser
    case userProfile
    case vote
    
    fileprivate var title: String {
        switch self {
        case .addBookmark: return "Bookmark"
        case .copyURL: return "Link"
        case .copyTitle: return "Copy Title"
        case .editPost: return "Edit"
        case .ignoreUser: return "Ignore User"
        case .jumpToFirstPage: return "First Page"
        case .jumpToLastPage: return "Last Page"
        case .markAsUnread: return "Mark Unread"
        case .markReadUpToHere: return "Mark Read"
        case .ownPosts: return "Your Posts"
        case .quotePost: return "Quote"
        case .copyPost: return "Copy Post"
        case .rapSheet: return "Rap Sheet"
        case .reportPost: return "Report"
        case .removeBookmark: return "Unmark"
        case .sendPrivateMessage: return "PM"
        case .showInThread: return "Find Post"
        case .singleUsersPosts: return "Their Posts"
        case .unignoreUser: return "Unignore"
        case .userProfile: return "Profile"
        case .vote: return "Vote"
        }
    }
    
    fileprivate var iconName: String {
        switch self {
        case .addBookmark: return "add-bookmark"
        case .copyURL: return "copy-url"
        case .copyTitle: return "copy-title"
        case .editPost: return "edit-post"
        case .ignoreUser: return "ignore"
        case .jumpToFirstPage: return "jump-to-first-page"
        case .jumpToLastPage: return "jump-to-last-page"
        case .markAsUnread: return "mark-as-unread"
        case .markReadUpToHere: return "mark-read-up-to-here"
        case .ownPosts: return "single-users-posts"
        case .quotePost: return "quote-post"
        case .copyPost: return "quote-post"
        case .rapSheet: return "rap-sheet"
        case .reportPost: return "rap-sheet"
        case .removeBookmark: return "remove-bookmark"
        case .sendPrivateMessage: return "send-private-message"
        case .showInThread: return "view-in-thread"
        case .singleUsersPosts: return "single-users-posts"
        case .unignoreUser: return "mark-read-up-to-here"
        case .userProfile: return "user-profile"
        case .vote: return "vote"
        }
    }
    
    fileprivate var themeKey: String {
        switch self {
        case .addBookmark: return "addBookmarkIconColor"
        case .copyURL: return "copyURLIconColor"
        case .copyTitle: return "copyTitleColor"
        case .editPost: return "editPostIconColor"
        case .ignoreUser: return "ignoreUserIconColor"
        case .jumpToFirstPage: return "jumpToFirstPageIconColor"
        case .jumpToLastPage: return "jumpToLastPageIconColor"
        case .markAsUnread: return "markUnreadIconColor"
        case .markReadUpToHere: return "markReadUpToHereIconColor"
        case .ownPosts: return "singleUserIconColor"
        case .quotePost: return "quoteIconColor"
        case .copyPost: return "quoteIconColor"
        case .rapSheet: return "rapSheetIconColor"
        case .reportPost: return "rapSheetIconColor"
        case .removeBookmark: return "removeBookmarkIconColor"
        case .sendPrivateMessage: return "sendPMIconColor"
        case .showInThread: return "showInThreadIconColor"
        case .singleUsersPosts: return "singleUserIconColor"
        case .unignoreUser: return "unignoreUserIconColor"
        case .userProfile: return "profileIconColor"
        case .vote: return "voteIconColor"
        }
    }
}
