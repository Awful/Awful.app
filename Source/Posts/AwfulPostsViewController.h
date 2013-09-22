//  AwfulPostsViewController.h
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulThreadPage.h"
@class AwfulThread;

@interface AwfulPostsViewController : AwfulViewController

@property (strong, nonatomic) AwfulThread *thread;

@property (readonly, nonatomic) AwfulThreadPage currentPage;

@property (copy, nonatomic) NSString *singleUserID;

- (void)loadPage:(AwfulThreadPage)page singleUserID:(NSString*) user;

- (void)jumpToPostWithID:(NSString *)postID;

@property (readonly, nonatomic) NSArray *posts;

@end
