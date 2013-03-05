//
//  AwfulPrivateMessageComposeViewController.m
//  Awful
//
//  Created by Nolan Waite on 2013-02-26.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulComposeField.h"
#import "AwfulHTTPClient.h"
#import "AwfulPostIconPickerController.h"
#import "AwfulThreadTags.h"
#import "SVProgressHUD.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulPrivateMessageComposeViewController () <AwfulPostIconPickerControllerDelegate>

@property (copy, nonatomic) NSString *recipient;
@property (copy, nonatomic) NSString *subject;
@property (copy, nonatomic) NSString *postIcon;
@property (copy, nonatomic) NSString *messageBody;
@property (nonatomic) AwfulPrivateMessage *regardingMessage;
@property (nonatomic) AwfulPrivateMessage *forwardedMessage;

- (NSString *)postIconIDForName:(NSString *)name;

@property (copy, nonatomic) NSDictionary *availablePostIcons;
@property (copy, nonatomic) NSArray *availablePostIconIDs;

@property (weak, nonatomic) UIButton *postIconButton;
@property (nonatomic) AwfulPostIconPickerController *postIconPicker;
@property (weak, nonatomic) AwfulComposeField *toField;
@property (weak, nonatomic) AwfulComposeField *subjectField;

@property (weak, nonatomic) NSOperation *networkOperation;

@end


@implementation AwfulPrivateMessageComposeViewController

- (void)didTapSend
{
    if ([self.recipient length] == 0) {
        [self.toField.textField becomeFirstResponder];
        return;
    }
    [self prepareToSendMessage];
}

- (void)send:(NSString *)messageBody
{
    id op = [[AwfulHTTPClient client] sendPrivateMessageTo:self.recipient
                                                   subject:self.subject
                                                      icon:[self postIconIDForName:self.postIcon]
                                                      text:self.textView.text
                                    asReplyToMessageWithID:self.regardingMessage.messageID
                                forwardedFromMessageWithID:self.forwardedMessage.messageID
                                                   andThen:^(NSError *error,
                                                             AwfulPrivateMessage *message)
    {
        if (error) {
            [SVProgressHUD dismiss];
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"
                               completion:^{
                self.textView.userInteractionEnabled = YES;
            }];
            return;
        }
        [SVProgressHUD showSuccessWithStatus:@"Sent"];
        [self.delegate privateMessageComposeControllerDidSendMessage:self];
    }];
    self.networkOperation = op;
}

- (NSString *)postIconIDForName:(NSString *)name
{
    if ([name length] == 0) return nil;
    for (NSString *key in self.availablePostIcons) {
        if ([self.availablePostIcons[key] isEqualToString:name]) {
            return key;
        }
    }
    return nil;
}

- (void)cancel
{
    [super cancel];
    [self.networkOperation cancel];
    if ([SVProgressHUD isVisible]) {
        [SVProgressHUD dismiss];
        self.textView.userInteractionEnabled = YES;
        [self.textView becomeFirstResponder];
    } else {
        SEL selector = @selector(privateMessageComposeControllerDidCancel:);
        if ([self.delegate respondsToSelector:selector]) {
            [self.delegate privateMessageComposeControllerDidCancel:self];
        }
    }
}

- (void)setRecipient:(NSString *)recipient
{
    if (_recipient == recipient) return;
    _recipient = [recipient copy];
    self.toField.textField.text = _recipient;
}

- (void)setSubject:(NSString *)subject
{
    if (_subject == subject) return;
    _subject = [subject copy];
    self.subjectField.textField.text = _subject;
}

- (void)setPostIcon:(NSString *)postIcon
{
    if (_postIcon == postIcon) return;
    _postIcon = [postIcon copy];
    [self.postIconButton setImage:[[AwfulThreadTags sharedThreadTags] threadTagNamed:postIcon]
                         forState:UIControlStateNormal];
}

- (void)setMessageBody:(NSString *)messageBody
{
    if (_messageBody == messageBody) return;
    _messageBody = [messageBody copy];
    self.textView.text = _messageBody;
}

- (void)setRegardingMessage:(AwfulPrivateMessage *)regardingMessage
{
    if (_regardingMessage == regardingMessage) return;
    _regardingMessage = regardingMessage;
    if (!regardingMessage) return;
    self.forwardedMessage = nil;
    self.recipient = regardingMessage.from.username;
    if ([regardingMessage.subject hasPrefix:@"Re: "]) {
        self.subject = regardingMessage.subject;
    } else {
        self.subject = [NSString stringWithFormat:@"Re: %@", regardingMessage.subject];
    }
}

- (void)setForwardedMessage:(AwfulPrivateMessage *)forwardedMessage
{
    if (_forwardedMessage == forwardedMessage) return;
    _forwardedMessage = forwardedMessage;
    if (!forwardedMessage) return;
    self.regardingMessage = nil;
    self.subject = [NSString stringWithFormat:@"Fw: %@", forwardedMessage.subject];
}

#pragma mark - AwfulComposeViewController

- (void)willTransitionToState:(AwfulComposeViewControllerState)state
{
    if (state == AwfulComposeViewControllerStateReady) {
        [self setTextFieldsAndViewUserInteractionEnabled:YES];
        if ([self.recipient length] == 0) {
            [self.toField.textField becomeFirstResponder];
        } else if ([self.subject length] == 0) {
            [self.subjectField.textField becomeFirstResponder];
        } else {
            [self.textView becomeFirstResponder];
        }
    } else {
        [self setTextFieldsAndViewUserInteractionEnabled:NO];
        [self.textView resignFirstResponder];
        [self.toField.textField resignFirstResponder];
        [self.subjectField.textField resignFirstResponder];
    }
    
    if (state == AwfulComposeViewControllerStateUploadingImages) {
        [SVProgressHUD showWithStatus:@"Uploading images…"];
    } else if (state == AwfulComposeViewControllerStateSending) {
        [SVProgressHUD showWithStatus:@"Sending…"];
    } else if (state == AwfulComposeViewControllerStateError) {
        [SVProgressHUD dismiss];
    }
}

- (void)setTextFieldsAndViewUserInteractionEnabled:(BOOL)enabled
{
    self.textView.userInteractionEnabled = enabled;
    self.toField.textField.userInteractionEnabled = enabled;
    self.subjectField.textField.userInteractionEnabled = enabled;
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.title = @"Private Message";
    self.sendButton.target = self;
    self.sendButton.action = @selector(didTapSend);
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancel);
    return self;
}

- (void)loadView
{
    const CGFloat fieldHeight = 88;
    self.textView.contentInset = UIEdgeInsetsMake(fieldHeight, 0, 0, 0);
    self.view = self.textView;
    
    UIView *topView = [UIView new];
    topView.frame = CGRectMake(0, -fieldHeight, CGRectGetWidth(self.textView.frame), fieldHeight);
    topView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1];
    [self.textView addSubview:topView];
    
    CGRect postIconFrame, fieldsFrame;
    CGRectDivide(topView.bounds, &postIconFrame, &fieldsFrame, 54, CGRectMaxXEdge);
    postIconFrame.origin.x += 1;
    postIconFrame.size.width -= 1;
    postIconFrame.size.height -= 1;
    UIButton *postIconButton = [[UIButton alloc] initWithFrame:postIconFrame];
    postIconButton.backgroundColor = [UIColor whiteColor];
    [postIconButton setTitle:@"Post Icon" forState:UIControlStateNormal];
    [postIconButton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
    postIconButton.titleLabel.font = [UIFont systemFontOfSize:14];
    postIconButton.titleLabel.numberOfLines = 0;
    postIconButton.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
    postIconButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    postIconButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [postIconButton addTarget:self action:@selector(didTapPostIcon)
             forControlEvents:UIControlEventTouchUpInside];
    [topView addSubview:postIconButton];
    self.postIconButton = postIconButton;
    
    CGRect toFrame, subjectFrame;
    CGRectDivide(fieldsFrame, &toFrame, &subjectFrame,
                 CGRectGetHeight(fieldsFrame) / 2 - 2, CGRectMinYEdge);
    subjectFrame.origin.y += 1;
    subjectFrame.size.height -= 2;
    AwfulComposeField *toField = [[AwfulComposeField alloc] initWithFrame:toFrame];
    toField.backgroundColor = [UIColor whiteColor];
    toField.label.text = @"To:";
    toField.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                                UIViewAutoresizingFlexibleWidth);
    toField.textField.keyboardAppearance = self.textView.keyboardAppearance;
    toField.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    toField.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    [topView addSubview:toField];
    self.toField = toField;
    
    AwfulComposeField *subjectField = [[AwfulComposeField alloc] initWithFrame:subjectFrame];
    subjectField.backgroundColor = toField.backgroundColor;
    subjectField.label.text = @"Subject:";
    subjectField.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                                     UIViewAutoresizingFlexibleWidth);
    subjectField.textField.keyboardAppearance = self.textView.keyboardAppearance;
    [topView addSubview:subjectField];
    self.subjectField = subjectField;
}

- (void)didTapPostIcon
{
    if (!self.postIconPicker) {
        self.postIconPicker = [[AwfulPostIconPickerController alloc] initWithDelegate:self];
    }
    if (self.postIcon) {
        for (id iconID in self.availablePostIcons) {
            if ([self.availablePostIcons[iconID] isEqual:self.postIcon]) {
                NSUInteger index = [self.availablePostIconIDs indexOfObject:iconID];
                self.postIconPicker.selectedIndex = index + 1;
                break;
            }
        }
    }
    if (self.postIconPicker.selectedIndex == NSNotFound) {
        self.postIconPicker.selectedIndex = 0;
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.postIconPicker showFromRect:self.postIconButton.frame
                                   inView:self.postIconButton.superview];
    } else {
        [self presentViewController:[self.postIconPicker enclosingNavigationController] animated:YES
                         completion:nil];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.toField.textField.text = self.recipient;
    self.subjectField.textField.text = self.subject;
    [self.postIconButton setImage:[[AwfulThreadTags sharedThreadTags] threadTagNamed:self.postIcon]
                         forState:UIControlStateNormal];
    [[AwfulHTTPClient client] listAvailablePrivateMessagePostIconsAndThen:
     ^(NSError *error, NSDictionary *postIcons, NSArray *postIconIDs)
    {
        NSMutableDictionary *postIconNames = [NSMutableDictionary new];
        for (id key in postIcons) {
            postIconNames[key] = [[postIcons[key] lastPathComponent] stringByDeletingPathExtension];
        }
        self.availablePostIcons = postIconNames;
        self.availablePostIconIDs = postIconIDs;
        [self.postIconPicker reloadData];
    }];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    // In case the view gets unloaded (has been problem on iOS 5.)
    // TODO: see if this is still a problem.
    self.recipient = self.toField.textField.text;
    self.subject = self.subjectField.textField.text;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self.postIconPicker showFromRect:self.postIconButton.frame
                               inView:self.postIconButton.superview];
}

#pragma mark - AwfulPostIconPickerControllerDelegate

- (NSInteger)numberOfIconsInPostIconPicker:(AwfulPostIconPickerController *)picker
{
    return [self.availablePostIconIDs count] + 1;
}

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker postIconAtIndex:(NSInteger)index
{
    if (index == 0) {
        return nil; // TODO proper "no icon" icon
    }
    index -= 1;
    NSString *iconName = self.availablePostIcons[self.availablePostIconIDs[index]];
    // TODO handle downloading new thread tags
    return [[AwfulThreadTags sharedThreadTags] threadTagNamed:iconName];
}

- (void)postIconPickerDidComplete:(AwfulPostIconPickerController *)picker
{
    if (picker.selectedIndex == 0) {
        [self setPostIcon:nil];
    } else {
        id selectedIconID = self.availablePostIconIDs[picker.selectedIndex - 1];
        [self setPostIcon:self.availablePostIcons[selectedIconID]];
    }
    self.postIconPicker = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)postIconPickerDidCancel:(AwfulPostIconPickerController *)picker
{
    self.postIconPicker = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)postIconPicker:(AwfulPostIconPickerController *)picker didSelectIconAtIndex:(NSInteger)index
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (index == 0) {
            [self setPostIcon:nil];
        } else {
            id selectedIconID = self.availablePostIconIDs[index - 1];
            [self setPostIcon:self.availablePostIcons[selectedIconID]];
        }
    }
}

@end
