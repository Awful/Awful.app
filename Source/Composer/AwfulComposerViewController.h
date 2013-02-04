//
//  AwfulEditorViewController.h
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//
#import <UIKit/UIKit.h>
#import "AwfulModels.h"
#import "AwfulHTTPClient.h"
#import "AwfulAlertView.h"
#import "NSString+CollapseWhitespace.h"

#import "ImgurHTTPClient.h"
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"
#import "AwfulComposerView.h"
#import "AwfulTableViewController.h"

@protocol AwfulComposerViewControllerDelegate;


@interface AwfulComposerViewController : AwfulTableViewController <AwfulComposerViewDelegate>

@property (weak, nonatomic) id <AwfulComposerViewControllerDelegate> delegate;
@property (readonly, nonatomic) AwfulComposerView *composerTextView;
@property (nonatomic) id <ImgurHTTPClientCancelToken> imageUploadCancelToken;
@property (strong, nonatomic) UIBarButtonItem *sendButton;
@property (strong, nonatomic) UIBarButtonItem *cancelButton;
@property (nonatomic) id observerToken;
@property (nonatomic) UIPopoverController *pickerPopover;
@property (nonatomic) NSMutableDictionary *images;
@property (nonatomic,weak) AwfulAlertView* confirmationAlert;
@property (nonatomic,strong) AwfulEmoticonKeyboardController* emoticonChooser;

- (void)cancel;
- (void)send;
- (void)didReplaceImagePlaceholders:(NSString*)newMessageString;

@end

@protocol AwfulComposerViewControllerDelegate <NSObject>

- (void)composerViewController:(AwfulComposerViewController *)composerViewController didSend:(id)post;

- (void)composerViewControllerDidCancel:(AwfulComposerViewController *)composerViewController;

@end
