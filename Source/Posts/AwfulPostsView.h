//
//  AwfulPostsView.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-29.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AwfulPostsViewDelegate;


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

// Set to nil to hide loading screen.
@property (copy, nonatomic) NSString *loadingMessage;

// Set to nil to hide end of thread message.
@property (copy, nonatomic) NSString *endMessage;

@end


@protocol AwfulPostsViewDelegate <NSObject>

@required

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView;

- (NSDictionary *)postsView:(AwfulPostsView *)postsView postAtIndex:(NSInteger)index;

@optional

- (NSString *)advertisementHTMLForPostsView:(AwfulPostsView *)postsView;

- (void)postsView:(AwfulPostsView *)postsView didTapLinkToURL:(NSURL *)url;

// In addition to the methods listed in this protocol, the delegate can have arbitrary methods
// called from JavaScript running in the posts view. Parameters to methods called this way will be
// Foundation objects allowed in JSON.

// This is part of the JavaScript to Objective-C one-way bridge. NSObject and NSProxy already
// implement this method, so you probably don't need to do anything.
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;

@end
