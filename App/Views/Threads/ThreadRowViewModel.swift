//  ThreadRowViewModel.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulModelTypes
import AwfulTheming
import SwiftUI
import UIKit

struct ThreadRowViewModel: Identifiable {
    let id: String
    let backgroundColor: Color
    let pageCount: String
    let pageCountColor: Color
    let pageIconColor: Color
    let postInfo: String
    let postInfoColor: Color
    let ratingImage: UIImage?
    let secondaryTagImageName: String?
    let selectedBackgroundColor: Color
    let stickyImage: UIImage?
    let tagImageName: String?
    let tagImagePlaceholder: ThreadTagLoader.Placeholder?
    let title: String
    let titleColor: Color
    let titleFont: UIFont
    let unreadCount: String
    let unreadCountColor: Color
    let unreadCountFont: UIFont
    let showTagAndRating: Bool
    let isSticky: Bool
    let isClosed: Bool
    let hasUnreadPosts: Bool
    let pageCountFont: UIFont
    let postInfoFont: UIFont
    
    init(thread: AwfulThread, theme: Theme, showsTagAndRating: Bool, ignoreSticky: Bool = false, placeholder: ThreadTagLoader.Placeholder = .thread(tintColor: nil)) {
        let tweaks = thread.forum.flatMap { ForumTweaks(ForumID($0.forumID)) }
        
        self.id = thread.threadID
        self.backgroundColor = Color(theme[uicolor: "listBackgroundColor"]!)
        self.selectedBackgroundColor = Color(theme[uicolor: "listSelectedBackgroundColor"]!)
        self.showTagAndRating = showsTagAndRating
        self.isSticky = thread.sticky
        self.isClosed = thread.closed
        self.hasUnreadPosts = thread.anyUnreadPosts
        
        // Page count
        self.pageCount = "\(thread.numberOfPages)"
        self.pageCountFont = UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"], sizeAdjustment: 0, weight: .semibold)
        self.pageCountColor = Color(theme[uicolor: "listSecondaryTextColor"]!)
        self.pageIconColor = Color(theme[uicolor: "threadListPageIconColor"]!)
        
        // Post info
        let postInfoText: String
        if thread.beenSeen {
            postInfoText = String(format: LocalizedString("thread-list.killed-by"), thread.lastPostAuthorName ?? "")
        } else {
            postInfoText = String(format: LocalizedString("thread-list.posted-by"), thread.author?.username ?? "")
        }
        self.postInfo = postInfoText
        self.postInfoFont = UIFont.preferredFontForTextStyle(.footnote, fontName: theme["listFontName"], sizeAdjustment: 0, weight: .semibold)
        self.postInfoColor = Color(theme[uicolor: "listSecondaryTextColor"]!)
        
        // Rating image
        if showsTagAndRating && !(tweaks?.showRatingsAsThreadTags ?? false) {
            self.ratingImage = thread.ratingImageName.flatMap { imageName in
                if imageName != "Vote0" {
                    return UIImage(named: "Vote0")!
                        .withTintColor(Theme.defaultTheme()["ratingIconEmptyColor"]!)
                        .mergeWith(topImage: UIImage(named: imageName)!)
                }
                return nil  // Don't show rating bars for threads with no rating
            }
        } else {
            self.ratingImage = nil
        }
        
        // Secondary tag
        if showsTagAndRating {
            self.secondaryTagImageName = thread.secondaryThreadTag?.imageName
        } else {
            self.secondaryTagImageName = nil
        }
        
        // Sticky image
        self.stickyImage = !ignoreSticky && thread.sticky ? UIImage(named: "sticky") : nil
        
        // Tag image
        if showsTagAndRating {
            if let tweaks = tweaks, tweaks.showRatingsAsThreadTags, let imageName = thread.ratingTagImageName {
                self.tagImageName = imageName
                self.tagImagePlaceholder = placeholder
            } else {
                self.tagImageName = thread.threadTag?.imageName
                self.tagImagePlaceholder = placeholder
            }
        } else {
            self.tagImageName = nil
            self.tagImagePlaceholder = nil
        }
        
        // Title
        self.title = thread.title ?? ""
        self.titleFont = UIFont.preferredFontForTextStyle(.body, fontName: theme["listFontName"], sizeAdjustment: 0, weight: .regular)
        self.titleColor = Color(theme[uicolor: thread.closed ? "listSecondaryTextColor" : "listTextColor"]!)
        
        // Unread count
        if thread.beenSeen {
            let color: UIColor
            if thread.unreadPosts == 0 {
                color = theme["unreadBadgeGrayColor"]!
            } else {
                switch thread.starCategory {
                case .orange: color = theme["unreadBadgeOrangeColor"]!
                case .red: color = theme["unreadBadgeRedColor"]!
                case .yellow: color = theme["unreadBadgeYellowColor"]!
                case .cyan: color = theme["unreadBadgeCyanColor"]!
                case .green: color = theme["unreadBadgeGreenColor"]!
                case .purple: color = theme["unreadBadgePurpleColor"]!
                case .none: color = theme["unreadBadgeBlueColor"]!
                }
            }
            self.unreadCount = "\(thread.unreadPosts)"
            self.unreadCountColor = Color(color)
            self.unreadCountFont = UIFont.preferredFontForTextStyle(.caption1, fontName: theme["listFontName"], sizeAdjustment: 1, weight: .semibold)
        } else {
            self.unreadCount = ""
            self.unreadCountColor = Color.clear
            self.unreadCountFont = UIFont.preferredFontForTextStyle(.caption1, fontName: theme["listFontName"], sizeAdjustment: 1, weight: .semibold)
        }
    }
}

extension ThreadRowViewModel {
    static let empty = ThreadRowViewModel(
        id: "",
        backgroundColor: Color.clear,
        pageCount: "",
        pageCountColor: Color.clear,
        pageIconColor: Color.clear,
        postInfo: "",
        postInfoColor: Color.clear,
        ratingImage: nil,
        secondaryTagImageName: nil,
        selectedBackgroundColor: Color.clear,
        stickyImage: nil,
        tagImageName: nil,
        tagImagePlaceholder: nil,
        title: "",
        titleColor: Color.clear,
        titleFont: UIFont.systemFont(ofSize: 17),
        unreadCount: "",
        unreadCountColor: Color.clear,
        unreadCountFont: UIFont.systemFont(ofSize: 12),
        showTagAndRating: false,
        isSticky: false,
        isClosed: false,
        hasUnreadPosts: false,
        pageCountFont: UIFont.systemFont(ofSize: 12),
        postInfoFont: UIFont.systemFont(ofSize: 11)
    )
    
    private init(id: String, backgroundColor: Color, pageCount: String, pageCountColor: Color, pageIconColor: Color, postInfo: String, postInfoColor: Color, ratingImage: UIImage?, secondaryTagImageName: String?, selectedBackgroundColor: Color, stickyImage: UIImage?, tagImageName: String?, tagImagePlaceholder: ThreadTagLoader.Placeholder?, title: String, titleColor: Color, titleFont: UIFont, unreadCount: String, unreadCountColor: Color, unreadCountFont: UIFont, showTagAndRating: Bool, isSticky: Bool, isClosed: Bool, hasUnreadPosts: Bool, pageCountFont: UIFont, postInfoFont: UIFont) {
        self.id = id
        self.backgroundColor = backgroundColor
        self.pageCount = pageCount
        self.pageCountColor = pageCountColor
        self.pageIconColor = pageIconColor
        self.postInfo = postInfo
        self.postInfoColor = postInfoColor
        self.ratingImage = ratingImage
        self.secondaryTagImageName = secondaryTagImageName
        self.selectedBackgroundColor = selectedBackgroundColor
        self.stickyImage = stickyImage
        self.tagImageName = tagImageName
        self.tagImagePlaceholder = tagImagePlaceholder
        self.title = title
        self.titleColor = titleColor
        self.titleFont = titleFont
        self.unreadCount = unreadCount
        self.unreadCountColor = unreadCountColor
        self.unreadCountFont = unreadCountFont
        self.showTagAndRating = showTagAndRating
        self.isSticky = isSticky
        self.isClosed = isClosed
        self.hasUnreadPosts = hasUnreadPosts
        self.pageCountFont = pageCountFont
        self.postInfoFont = postInfoFont
    }
}