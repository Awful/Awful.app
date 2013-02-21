//
//  AwfulPostsViewController.h
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
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
