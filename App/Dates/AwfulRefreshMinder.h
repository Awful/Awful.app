//  AwfulRefreshMinder.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;
@import AwfulCore;

/**
 * An AwfulRefreshMinder remembers when various actions were last performed.
 */
@interface AwfulRefreshMinder : NSObject

/**
 * Singleton instance that uses +[NSUserDefaults standardUserDefaults].
 */
+ (instancetype)minder;

/// Swift-able accessor for the singleton instance.
+ (instancetype)sharedMinder;

- (instancetype)initWithUserDefaults:(NSUserDefaults *)userDefaults NS_DESIGNATED_INITIALIZER;

/**
 * The backing store for the recorded refresh dates.
 */
@property (readonly, strong, nonatomic) NSUserDefaults *userDefaults;

/**
 * Permanently forget all stored refresh dates. This will effectively trigger refreshes everywhere.
 */
- (void)forgetEverything;

- (BOOL)shouldRefreshAvatar;

- (void)didFinishRefreshingAvatar;

- (BOOL)shouldRefreshBookmarks;

- (void)didFinishRefreshingBookmarks;

- (BOOL)shouldRefreshForum:(Forum *)forum;

- (void)didFinishRefreshingForum:(Forum *)forum;

- (BOOL)shouldRefreshFilteredForum:(Forum *)forum;

- (void)didFinishRefreshingFilteredForum:(Forum *)forum;

- (void)forgetForum:(Forum *)forum;

- (BOOL)shouldRefreshForumList;

- (void)didFinishRefreshingForumList;

- (BOOL)shouldRefreshLoggedInUser;

- (void)didFinishRefreshingLoggedInUser;

- (BOOL)shouldRefreshPrivateMessagesInbox;

- (void)didFinishRefreshingPrivateMessagesInbox;

- (BOOL)shouldRefreshNewPrivateMessages;

- (void)didFinishRefreshingNewPrivateMessages;

- (NSDate *)suggestedDateToRefreshNewPrivateMessages;

- (BOOL)shouldRefreshExternalStylesheet;

- (void)didFinishRefreshingExternalStylesheet;

- (NSDate *)suggestedDateToRefreshExternalStylesheet;

@end
