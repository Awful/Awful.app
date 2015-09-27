//  PostsPageViewController.h
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulViewController.h"
@import AwfulCore;

/**
 * A PostsPageViewController shows a list of posts in a thread.
 */
@interface PostsPageViewController : AwfulViewController

/**
 * @param thread The thread whose posts are shown.
 * @param author An optional author used to filter the shown posts. May be nil, in which case all posts are shown.
 */
- (instancetype)initWithThread:(Thread *)thread author:(User *)author NS_DESIGNATED_INITIALIZER;

/**
 * Calls -initWithThread:author: with a nil author.
 */
- (instancetype)initWithThread:(Thread *)thread noSeen:(bool)noSeen;

@property (readonly, strong, nonatomic) Thread *thread;

/**
 * An optional user whose posts are the only ones shown. If nil, all posts are shown.
 */
@property (readonly, strong, nonatomic) User *author;

/**
 * The currently-visible (or currently-loading) page of posts. Values of AwfulThreadPage are allowed here too (but it's typed NSInteger for Swift compatibility).
 */
@property (readonly, assign, nonatomic) NSInteger page;

/**
 * The number of pages in the thread, taking any filters into account.
 */
@property (readonly, assign, nonatomic) NSInteger numberOfPages;

/**
 * Changes the page.
 *
 * @param page        The page to load. Values of AwfulThreadPage are allowed here too (but it's typed NSInteger for Swift compatibility).
 * @param updateCache Whether to fetch posts from the client, or simply render any posts that are cached.
 */
- (void)loadPage:(NSInteger)page updatingCache:(BOOL)updateCache;

/**
 * An array of AwfulPost objects of the currently-visible posts.
 */
@property (readonly, copy, nonatomic) NSArray *posts;

/**
 * Scroll the posts view so that a particular post is visible (if the post is on the current(ly loading) page).
 */
- (void)scrollPostToVisible:(Post *)post;

@end
