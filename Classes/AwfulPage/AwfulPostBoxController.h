//
//  AwfulPostBoxController.h
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulThread;
@class AwfulPost;
@class AwfulPage;
@class MKNetworkOperation;

@interface AwfulPostBoxController : UIViewController <UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet UIBarButtonItem *sendButton;
@property (nonatomic, strong) IBOutlet UITextView *replyTextView;

@property (nonatomic, strong) AwfulThread *thread;
@property (nonatomic, strong) AwfulPost *post;
@property (nonatomic, strong) NSString *startingText;
@property (nonatomic, weak) AwfulPage *page;

@property (nonatomic, strong) MKNetworkOperation *networkOperation;

-(IBAction)hideReply;
-(IBAction)hitSend;
-(IBAction)hitTextBarButtonItem : (id)sender;

@end
