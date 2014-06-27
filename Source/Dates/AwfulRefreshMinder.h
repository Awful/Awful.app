//  AwfulRefreshMinder.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

/**
 * An AwfulRefreshMinder remembers when various actions were last performed.
 */
@interface AwfulRefreshMinder : NSObject

/**
 * Singleton instance that uses +[NSUserDefaults standardUserDefaults].
 */
+ (instancetype)minder;

/**
 * Designated initializer.
 */
- (id)initWithUserDefaults:(NSUserDefaults *)userDefaults;

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

- (BOOL)shouldRefreshForum:(AwfulForum *)forum;

- (void)didFinishRefreshingForum:(AwfulForum *)forum;

- (BOOL)shouldRefreshFilteredForum:(AwfulForum *)forum;

- (void)didFinishRefreshingFilteredForum:(AwfulForum *)forum;

- (void)forgetForum:(AwfulForum *)forum;

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
