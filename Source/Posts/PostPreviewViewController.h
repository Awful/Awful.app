//  PostPreviewViewController.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulViewController.h"
@class Post, Thread;

/**
 * A PostPreviewViewController previews a post (new or edited).
 */
@interface PostPreviewViewController : AwfulViewController

/**
 * Preview editing a post. One of two designated initializers.
 */
- (instancetype)initWithPost:(Post *)post BBcode:(NSAttributedString *)BBcode;

/**
 * Preview a new post. One of two designated initializers.
 */
- (instancetype)initWithThread:(Thread *)thread BBcode:(NSAttributedString *)BBcode;

@property (readonly, strong, nonatomic) Post *editingPost;

@property (readonly, strong, nonatomic) Thread *thread;

@property (readonly, copy, nonatomic) NSAttributedString *BBcode;

/**
 * A block to call if submission is to continue.
 */
@property (copy, nonatomic) void (^submitBlock)(void);

@end

@interface PostPreviewViewController (SubclassingHooks)

- (instancetype)initWithBBcode:(NSAttributedString *)BBcode;
- (void)fetchPreviewIfNecessary;
- (void)renderPreview;
@property (readonly, strong, nonatomic) Post *fakePost;
@property (readonly, strong, nonatomic) UIWebView *webView;

@end
