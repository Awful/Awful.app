//  AwfulPostsView.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
@protocol AwfulPostsViewDelegate;
@class AwfulSettings;

@interface AwfulPostsView : UIView

@property (weak, nonatomic) id <AwfulPostsViewDelegate> delegate;

- (void)reloadData;

- (void)reloadAdvertisementHTML;

- (void)beginUpdates;

- (void)insertPostAtIndex:(NSInteger)index;

- (void)deletePostAtIndex:(NSInteger)index;

- (void)reloadPostAtIndex:(NSInteger)index;

- (void)endUpdates;

- (void)clearAllPosts;

- (void)jumpToElementWithID:(NSString *)elementID;

@property (nonatomic) NSURL *stylesheetURL;

@property (getter=isDark, nonatomic) BOOL dark;

@property (nonatomic) BOOL showAvatars;

@property (nonatomic) BOOL showImages;

// Set to nil to highlight no quotes.
@property (copy, nonatomic) NSString *highlightQuoteUsername;

// Set to nil to highlight no mentions.
@property (copy, nonatomic) NSString *highlightMentionUsername;

@property (readonly, nonatomic) UIScrollView *scrollView;

// Set to nil to hide end of thread message.
@property (copy, nonatomic) NSString *endMessage;

// Returns the index of the post whose action button is at point, or NSNotFound on failure.
//
// point - A point in the posts view's frame coordinates.
// rect  - A pointer to a CGRect that, if non-NULL, will contain the bounds of the action button in
//         the posts view's frame coordinates on success.
- (NSInteger)indexOfPostWithActionButtonAtPoint:(CGPoint)point rect:(out CGRect *)rect;

// Returns the URL of the first image in a post at point, or nil on failure.
- (NSURL *)URLOfSpoiledImageForPoint:(CGPoint)point;

// Returns the URL of the first link in a post at point, or nil on failure.
//
// point - A point in the posts view's frame coordinates.
// rect  - A pointer to a CGRect that, if non-NULL, will contain the bounds of the link in the posts
//         view's frame coordinates on success.
- (NSURL *)URLOfSpoiledLinkForPoint:(CGPoint)point rect:(out CGRect *)rect;

// Returns the URL of the first video in a post at point, or nil on failure.
//
// point - A point in the posts view's frame coordinates.
// rect  - A pointer to a CGRect that, if non-NULL, will contain the bounds of the embedded video
//         in the posts view's frame coordinates on success.
- (NSURL *)URLOfSpoiledVideoForPoint:(CGPoint)point rect:(out CGRect *)rect;

@end


@protocol AwfulPostsViewDelegate <NSObject>

@required

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView;

// Returns an HTML representation of the requested post.
- (NSString *)postsView:(AwfulPostsView *)postsView renderedPostAtIndex:(NSInteger)index;

@optional

- (NSString *)advertisementHTMLForPostsView:(AwfulPostsView *)postsView;

- (void)postsView:(AwfulPostsView *)postsView willFollowLinkToURL:(NSURL *)url;
- (void)postsView:(AwfulPostsView *)postsView didReceiveSingleTapAtPoint:(CGPoint)point;
- (void)postsView:(AwfulPostsView *)postsView didReceiveLongTapAtPoint:(CGPoint)point;

@end


extern NSURL * StylesheetURLForForumWithIDAndSettings(NSString * const forumID,
                                                      AwfulSettings *settings);
