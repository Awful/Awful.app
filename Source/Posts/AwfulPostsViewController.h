//
//  AwfulPostsViewController.h
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>
#import "AwfulThreadPage.h"
@class AwfulThread;

@interface AwfulPostsViewController : UIViewController

@property (strong, nonatomic) AwfulThread *thread;

@property (readonly, nonatomic) AwfulThreadPage currentPage;

- (void)loadPage:(AwfulThreadPage)page;

- (void)jumpToPostWithID:(NSString *)postID;

@property (readonly, nonatomic) NSArray *posts;

@end
