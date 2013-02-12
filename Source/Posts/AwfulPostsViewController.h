//
//  AwfulPostsViewController.h
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AwfulThread;

@interface AwfulPostsViewController : UIViewController

@property (strong, nonatomic) AwfulThread *thread;

@property (assign, nonatomic) NSInteger currentPage;

- (void)loadPage:(NSInteger)page;

- (void)jumpToPostWithID:(NSString *)postID;

@property (readonly, nonatomic) NSArray *posts;

@end
