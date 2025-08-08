//  SendableConversions.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US

import CoreData
import Foundation

// MARK: - AwfulThread Conversions

extension AwfulThread {
    /// Creates a thread-safe representation of this thread for use across concurrency boundaries
    public var threadInfo: ThreadInfo {
        ThreadInfo(
            threadID: threadID,
            title: title,
            isBookmarked: bookmarked,
            isClosed: closed,
            seenPosts: seenPosts,
            totalReplies: totalReplies,
            threadListPage: threadListPage,
            bookmarkListPage: bookmarkListPage,
            starCategory: starCategory,
            isSticky: sticky,
            authorUserID: author?.userID,
            authorUsername: author?.username,
            forumID: forum?.forumID,
            threadTagID: threadTag?.threadTagID,
            secondaryThreadTagID: secondaryThreadTag?.threadTagID
        )
    }
    
    /// Convenience method to extract just the essential identifiers
    public var threadIdentifiers: (threadID: String, forumID: String?) {
        (threadID: threadID, forumID: forum?.forumID)
    }
}

// MARK: - User Conversions

extension User {
    /// Creates a thread-safe representation of this user for use across concurrency boundaries
    public var userInfo: UserInfo {
        UserInfo(
            userID: userID,
            username: username,
            isAdministrator: administrator,
            isModerator: moderator,
            canReceivePrivateMessages: canReceivePrivateMessages,
            regdate: regdate
        )
    }
    
    /// Convenience method to extract just the essential identifiers
    public var userIdentifiers: (userID: String, username: String?) {
        (userID: userID, username: username)
    }
}

// MARK: - Post Conversions

extension Post {
    /// Creates a thread-safe representation of this post for use across concurrency boundaries
    public var postInfo: PostInfo {
        PostInfo(
            postID: postID,
            threadID: thread?.threadID,
            authorUserID: author?.userID,
            authorUsername: author?.username,
            postDate: postDate,
            postIndex: threadIndex,
            isEditable: editable,
            isIgnored: ignored,
            page: Int32(page),
            singleUserPage: Int32(singleUserPage),
            innerHTML: innerHTML
        )
    }
    
    /// Convenience method to extract just the essential identifiers
    public var postIdentifiers: (postID: String, threadID: String?) {
        (postID: postID, threadID: thread?.threadID)
    }
}

// MARK: - Forum Conversions

extension Forum {
    /// Creates a thread-safe representation of this forum for use across concurrency boundaries
    public var forumInfo: ForumInfo {
        ForumInfo(
            forumID: forumID,
            name: name,
            canPost: canPost,
            parentForumID: parentForum?.forumID,
            index: index
        )
    }
    
    /// Convenience method to extract just the forum ID
    public var forumIdentifier: String {
        forumID
    }
}

// MARK: - PrivateMessage Conversions

extension PrivateMessage {
    /// Creates a thread-safe representation of this message for use across concurrency boundaries
    public var messageInfo: PrivateMessageInfo {
        PrivateMessageInfo(
            messageID: messageID,
            subject: subject,
            fromUserID: from?.userID,
            fromUsername: from?.username,
            toUserID: to?.userID,
            toUsername: to?.username,
            sentDate: sentDate,
            hasBeenSeen: seen,
            hasBeenForwarded: forwarded,
            hasBeenRepliedTo: replied
        )
    }
    
    /// Convenience method to extract just the message ID
    public var messageIdentifier: String {
        messageID
    }
}

// MARK: - ThreadTag Conversions

extension ThreadTag {
    /// Creates a thread-safe representation of this thread tag for use across concurrency boundaries
    public var tagInfo: ThreadTagInfo {
        ThreadTagInfo(
            threadTagID: threadTagID ?? "",
            imageName: imageName,
            threadTagName: nil
        )
    }
    
    /// Convenience method to extract just the tag ID
    public var tagIdentifier: String {
        threadTagID ?? ""
    }
}
