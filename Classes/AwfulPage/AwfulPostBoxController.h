//
//  AwfulPostBoxController.h
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulPost.h"

@class AwfulThread;

@interface AwfulPostBoxController : UIViewController <UIAlertViewDelegate>

@property (nonatomic, strong) IBOutlet UIBarButtonItem *sendButton;
@property (nonatomic, strong) IBOutlet UITextView *replyTextView;
@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property (nonatomic, strong) IBOutlet UIView *base;

@property (nonatomic, strong) AwfulThread *thread;
@property (nonatomic, strong) AwfulPost *post;
@property (nonatomic, strong) NSString *startingText;

-(id)initWithText : (NSString *)text;
-(IBAction)hideReply;
-(IBAction)hitSend;
-(void)addText : (NSString *)in_text;

+(void)savePost : (NSString *)text;
+(NSString *)retrievePost;
+(void)clearStoredPost;

@end
