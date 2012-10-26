//
//  AwfulReplyViewController.h
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulThread;
@class AwfulPage;
@class PostParsedInfo;

@interface AwfulReplyViewController : UIViewController

@property (strong, nonatomic) AwfulThread *thread;
@property (strong, nonatomic) PostParsedInfo *post;
@property (strong, nonatomic) NSString *startingText;
@property (weak, nonatomic) AwfulPage *page;

@end
