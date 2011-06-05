//
//  AwfulPostBoxController.h
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulPost.h"
#import "AwfulThread.h"

@interface AwfulPostBoxController : UIViewController <UIAlertViewDelegate> {
    UIButton *sendButton;
    UIButton *cancelButton;
    UIButton *clearButton;
    UITextView *replyTextView;
    UIView *buttonGroup;
    
    AwfulThread *thread;
    AwfulPost *post;
    NSString *startingText;
}

@property (nonatomic, retain) IBOutlet UIButton *sendButton;
@property (nonatomic, retain) IBOutlet UIButton *cancelButton;
@property (nonatomic, retain) IBOutlet UIButton *clearButton;
@property (nonatomic, retain) IBOutlet UITextView *replyTextView;
@property (nonatomic, retain) IBOutlet UIView *buttonGroup;

-(id)initWithText : (NSString *)text;

-(IBAction)hideReply;
-(IBAction)clearReply;
-(IBAction)hitSend;

-(void)setReplyBox : (AwfulThread *)in_thread;
-(void)setEditBox : (AwfulPost *)in_post;
-(void)addText : (NSString *)in_text;

@end
