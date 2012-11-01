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

- (void)showHiddenSeenPosts;

- (void)clearAllPosts;

@property (nonatomic) NSURL *stylesheetURL;

@property (getter=isDark, nonatomic) BOOL dark;

@property (nonatomic) NSInteger previouslySeenPostsToShow;

@property (readonly, nonatomic) UIScrollView *scrollView;

@end


@protocol AwfulPostsViewDelegate <NSObject>

@required

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView;

- (NSDictionary *)postsView:(AwfulPostsView *)postsView postAtIndex:(NSInteger)index;

@optional

- (void)postsView:(AwfulPostsView *)postsView numberOfHiddenSeenPosts:(NSInteger)hiddenPosts;

- (void)postsView:(AwfulPostsView *)postsView didTapLinkToURL:(NSURL *)url;

// In addition to the methods listed in this protocol, the delegate can have arbitrary methods
// called from JavaScript running in the posts view. Parameters to methods called this way will be
// Foundation objects allowed in JSON.

// This is part of the JavaScript to Objective-C one-way bridge. NSObject and NSProxy already
// implement this method, so you probably don't need to do anything.
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector;

@end
