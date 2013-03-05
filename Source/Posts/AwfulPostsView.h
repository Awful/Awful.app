//
//  AwfulPostsView.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-29.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
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

@property (nonatomic) NSNumber *fontScale;

// Set to nil to highlight no quotes.
@property (copy, nonatomic) NSString *highlightQuoteUsername;

// Set to nil to highlight no mentions.
@property (copy, nonatomic) NSString *highlightMentionUsername;

@property (readonly, nonatomic) UIScrollView *scrollView;

// Set to nil to hide loading screen.
@property (copy, nonatomic) NSString *loadingMessage;

// Set to nil to hide end of thread message.
@property (copy, nonatomic) NSString *endMessage;

@end


@protocol AwfulPostsViewDelegate <NSObject>

@required

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView;

// Returns a dictionary with values for keys in AwfulPostsViewKeys. All keys are optional.
- (NSDictionary *)postsView:(AwfulPostsView *)postsView postAtIndex:(NSInteger)index;

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


extern const struct AwfulPostsViewKeys
{
    // NSString: The HTML contents of the post.
    __unsafe_unretained NSString *innerHTML;
    
    // NSString: The post's ID, for the post HTML element's `id` attribute and for locating an
    // attachment.
    __unsafe_unretained NSString *postID;
    
    // NSString: When the post was made.
    __unsafe_unretained NSString *postDate;
    
    // NSString: The author's username.
    __unsafe_unretained NSString *authorName;
    
    // NSString: The absolute URL to the author's avatar.
    __unsafe_unretained NSString *authorAvatarURL;
    
    // NSNumber(BOOL): YES if the author is the thread's original poster.
    __unsafe_unretained NSString *authorIsOriginalPoster;
    
    // NSNumber(BOOL): YES if the author is a moderator of any forum.
    __unsafe_unretained NSString *authorIsAModerator;
    
    // NSNumber(BOOL): YES if the author is an administrator.
    __unsafe_unretained NSString *authorIsAnAdministrator;
    
    // NSString: When the author registered their account.
    __unsafe_unretained NSString *authorRegDate;
    
    // NSNumber(BOOL): YES if the post has an attached image. The postID is used to retrieve the
    // image.
    __unsafe_unretained NSString *hasAttachment;
    
    // NSString: If the post has been edited, a message including the editor and edit date.
    __unsafe_unretained NSString *editMessage;
    
    // NSNumber(BOOL): YES if the post has been seen.
    __unsafe_unretained NSString *beenSeen;
} AwfulPostsViewKeys;


extern NSURL * StylesheetURLForForumWithIDAndSettings(NSString * const forumID,
                                                      AwfulSettings *settings);
