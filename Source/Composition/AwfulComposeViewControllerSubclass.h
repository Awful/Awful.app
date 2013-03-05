//
//  AwfulComposeViewControllerSubclass.h
//  Awful
//
//  Created by Nolan Waite on 2013-02-26.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposeViewController.h"

typedef NS_ENUM(NSInteger, AwfulComposeViewControllerState) {
    // The compose controller isn't doing anything.
    AwfulComposeViewControllerStateReady,
    
    // The compose controller is uploading images.
    AwfulComposeViewControllerStateUploadingImages,
    
    // The compose controller is sending its contents.
    AwfulComposeViewControllerStateSending,
    
    // The compose controller cannot continue and will show an error.
    AwfulComposeViewControllerStateError,
};

@interface AwfulComposeViewController ()

// By default, the sendButton has no target or action. Subclasses should set both of these
// properties. Its default title is "Send".
@property (nonatomic) UIBarButtonItem *sendButton;

// By default, the sendButton has no target or action. Subclasses should set both of these
// properties. Its default title is "Cancel".
@property (nonatomic) UIBarButtonItem *cancelButton;

// Sent when the view appears and whenever the user changes the current theme. Subclasses can call
// super to get default light/dark theme changes.
- (void)retheme;

// Subclasses should send -prepareToSendMessage so the compose controller can upload images and do
// any other preparatory work. When complete, your subclass will receive a -send message to perform
// the final step.
- (void)prepareToSendMessage;

// Subclasses must implement -send:.
//
// messageBody - The prepared message to send. This may differ from the text view's contents by,
//               for example, replacing image placeholders with working URLs.
- (void)send:(NSString *)messageBody;

// Sent when the user wishes to cancel sending a message. Subclasses should call super to cancel
// image uploading.
- (void)cancel;

// Sent when the compose controller is about to change its state. Subclasses can override to, for
// example, inform the user when images are being uploaded or messages are being sent.
- (void)willTransitionToState:(AwfulComposeViewControllerState)state;

// The compose controller's current state. Please pretend this is readonly.
// TODO mark as readonly, privately mark as readwrite.
@property (nonatomic) AwfulComposeViewControllerState state;

@end
