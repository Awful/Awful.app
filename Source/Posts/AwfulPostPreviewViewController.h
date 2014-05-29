//  AwfulPostPreviewViewController.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulModels.h"

/**
 * An AwfulPostPreviewViewController previews a post (new or edited).
 */
@interface AwfulPostPreviewViewController : AwfulViewController

/**
 * Preview editing a post. One of two designated initializers.
 */
- (id)initWithPost:(AwfulPost *)post BBcode:(NSString *)BBcode;

/**
 * Preview a new post. One of two designated initializers.
 */
- (id)initWithThread:(AwfulThread *)thread BBcode:(NSString *)BBcode;

@property (readonly, strong, nonatomic) AwfulPost *editingPost;

@property (readonly, strong, nonatomic) AwfulThread *thread;

@property (readonly, copy, nonatomic) NSString *BBcode;

/**
 * A block to call if submission is to continue.
 */
@property (copy, nonatomic) void (^submitBlock)(void);

@end
