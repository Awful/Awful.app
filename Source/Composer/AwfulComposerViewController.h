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

#define RICH_TEXT_EDITOR_SUPPORT ([[[UIDevice currentDevice] systemVersion] floatValue] >= 6.0f)

@protocol AwfulComposerViewControllerDelegate;

@interface AwfulComposerViewController : UIViewController

@property (weak, nonatomic) id <AwfulComposerViewControllerDelegate> delegate;
@property (readonly, nonatomic) UITextView *composerTextView;
@property (nonatomic) id <ImgurHTTPClientCancelToken> imageUploadCancelToken;
@property (strong, nonatomic) UIBarButtonItem *sendButton;
@property (strong, nonatomic) UIBarButtonItem *cancelButton;
@property (weak, nonatomic) NSOperation *networkOperation;
@property (nonatomic) id observerToken;
@property (nonatomic) UIPopoverController *pickerPopover;
@property (nonatomic) NSMutableDictionary *images;
@property (nonatomic,weak) AwfulAlertView* confirmationAlert;

- (void)cancel;
- (void)send;
- (void)didReplaceImagePlaceholders:(NSString*)newMessageString;

@end

@protocol AwfulComposerViewControllerDelegate <NSObject>

- (void)composerViewController:(AwfulComposerViewController *)composerViewController didSend:(id)post;

- (void)composerViewControllerDidCancel:(AwfulComposerViewController *)composerViewController;

@end
