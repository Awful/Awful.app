//
//  AwfulPostsView.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

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

// Font size in pixels. Default is 15.
@property (nonatomic) NSNumber *fontSize;

// Set to nil to highlight no quotes.
@property (copy, nonatomic) NSString *highlightQuoteUsername;

// Set to nil to highlight no mentions.
@property (copy, nonatomic) NSString *highlightMentionUsername;

@property (readonly, nonatomic) UIScrollView *scrollView;

// Set to nil to hide end of thread message.
@property (copy, nonatomic) NSString *endMessage;

// Extract an Objective-C invocation from a URL and send it if the selector is in the whitelist.
extern void InvokeBridgedMethodWithURLAndTarget(NSURL *url, id target, NSArray *whitelist);

@end


@protocol AwfulPostsViewDelegate <NSObject>

@required

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView;

// Returns an HTML representation of the requested post.
- (NSString *)postsView:(AwfulPostsView *)postsView renderedPostAtIndex:(NSInteger)index;

@optional

- (NSString *)advertisementHTMLForPostsView:(AwfulPostsView *)postsView;

- (void)postsView:(AwfulPostsView *)postsView didTapLinkToURL:(NSURL *)url;

// In addition to the methods listed in this protocol, the delegate can have arbitrary methods
// called from JavaScript running in the posts view. Parameters to methods called this way will be
// Foundation objects allowed in JSON.
//
// Only the methods whose selectors are in the whitelist will be called. If this method is not
// implemented, nothing is called.
- (NSArray *)whitelistedSelectorsForPostsView:(AwfulPostsView *)postsView;

@required

// This is part of the JavaScript to Objective-C one-way bridge. NSObject and NSProxy already
// implement this method, so you probably don't need to do anything.
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;

@end


extern NSURL * StylesheetURLForForumWithIDAndSettings(NSString * const forumID,
                                                      AwfulSettings *settings);
