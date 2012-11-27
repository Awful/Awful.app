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

@property (nonatomic, strong) AwfulThread *thread;

@property (nonatomic, assign) NSInteger currentPage;

- (void)loadPage:(NSInteger)page;

- (void)jumpToPostWithID:(NSString *)postID;

@end
