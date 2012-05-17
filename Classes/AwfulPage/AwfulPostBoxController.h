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
@class ButtonSegmentedControl;
@class EGOTextView;
@class AwfulPostComposerView;

typedef enum {
    PostEditorSegmentEmote,
    PostEditorSegmentImage,
    PostEditorSegmentFormat

} PostEditorSegment;


@interface AwfulPostBoxController : UIViewController <UIAlertViewDelegate, UIActionSheetDelegate> {
    UIPopoverController *pop;
}

@property (nonatomic, strong) IBOutlet UIBarButtonItem *sendButton;
@property (nonatomic, strong) IBOutlet EGOTextView *replyTextView;
@property (nonatomic, strong) IBOutlet AwfulPostComposerView *replyWebView;
@property (nonatomic, strong) IBOutlet ButtonSegmentedControl *segmentedControl;
@property (nonatomic,strong) UIPopoverController *popoverController;

@property (nonatomic, strong) AwfulThread *thread;
@property (nonatomic, strong) AwfulPost *post;
@property (nonatomic, strong) NSString *startingText;
@property (nonatomic, weak) AwfulPage *page;

@property (nonatomic, strong) MKNetworkOperation *networkOperation;

-(IBAction)hideReply;
-(IBAction)hitSend;
-(IBAction)hitTextBarButtonItem : (NSString *)str;
-(void)tappedSegment : (id)sender;

-(void) didChooseEmote:(NSNotification*)emoteSelectedNotification;

@end
