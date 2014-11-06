//  Handoff.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

#pragma mark Common to several activity types

/// An NSNumber included in all Handoff userInfo dictionaries for future-proofing.
extern NSString * const HandoffInfoVersionKey;

/// An NSNumber indicating the page of a forum or thread.
extern NSString * const HandoffInfoPageKey;

#pragma mark Page of posts

/// Equivalent to showthread.php
extern NSString * const HandoffActivityTypeBrowsingPosts;

/// An NSString of the thread's ID.
extern NSString * const HandoffInfoThreadIDKey;

/// An NSString of the currently-visible post's ID.
extern NSString * const HandoffInfoPostIDKey;

/// An NSString of the author's user ID, if the posts are being filtered by author.
extern NSString * const HandoffInfoFilteredThreadUserIDKey;

// HandoffInfoPageKey may appear here as well. If it is absent, assume page 1.

#pragma mark Page of threads

/// Equivalent to forumdisplay.php or bookmarkthreads.php
extern NSString * const HandoffActivityTypeListingThreads;

/// An NSString of the forum's ID. Present only when a forum's threads are being listed.
extern NSString * const HandoffInfoForumIDKey;

/// An NSNumber `@YES`, present only when the user's bookmarked threads are being listed.
extern NSString * const HandoffInfoBookmarksKey;

// HandoffInfoPageKey may appear here as well. If it is absent, assume page 1.

#pragma mark Private message

/// Equivalent to private.php?action=show
extern NSString * const HandoffActivityTypeReadingMessage;

/// An NSString of the private message's ID.
extern NSString * const HandoffInfoMessageIDKey;
