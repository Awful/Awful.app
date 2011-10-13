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

@interface AwfulPostBoxController : UIViewController <UIAlertViewDelegate> {
    UITextView *_replyTextView;
    UIBarButtonItem *_sendButton;
    UIToolbar *_toolbar;
    UIView *_base;
    
    AwfulThread *_thread;
    AwfulPost *_post;
    NSString *_startingText;
}

@property (nonatomic, retain) IBOutlet UIBarButtonItem *sendButton;
@property (nonatomic, retain) IBOutlet UITextView *replyTextView;
@property (nonatomic, retain) IBOutlet UIToolbar *toolbar;
@property (nonatomic, retain) IBOutlet UIView *base;

@property (nonatomic, retain) AwfulThread *thread;
@property (nonatomic, retain) AwfulPost *post;
@property (nonatomic, retain) NSString *startingText;

-(id)initWithText : (NSString *)text;
-(IBAction)hideReply;
-(IBAction)hitSend;
-(void)addText : (NSString *)in_text;

+(void)savePost : (NSString *)text;
+(NSString *)retrievePost;
+(void)clearStoredPost;

@end
