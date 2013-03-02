//
//  AwfulPrivateMessageComposeViewController.m
//  Awful
//
//  Created by Nolan Waite on 2013-02-26.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulComposeField.h"
#import "SVProgressHUD.h"

@interface AwfulPrivateMessageComposeViewController ()

@property (copy, nonatomic) NSString *recipient;
@property (copy, nonatomic) NSString *subject;
@property (copy, nonatomic) NSString *postIcon;
@property (copy, nonatomic) NSString *messageBody;
@property (nonatomic) AwfulPrivateMessage *regardingMessage;

@property (weak, nonatomic) UIButton *postIconButton;
@property (weak, nonatomic) AwfulComposeField *toField;
@property (weak, nonatomic) AwfulComposeField *subjectField;

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
    // TODO actually send
    if (self.regardingMessage) {
        SEL selector = @selector(privateMessageComposeController:didReplyToMessage:);
        if ([self.delegate respondsToSelector:selector]) {
            [self.delegate privateMessageComposeController:self
                                         didReplyToMessage:self.regardingMessage];
        }
    } else {
        SEL selector = @selector(privateMessageComposeControllerDidSendMessage:);
        if ([self.delegate respondsToSelector:selector]) {
            [self.delegate privateMessageComposeControllerDidSendMessage:self];
        }
    }
}

- (void)cancel
{
    [super cancel];
    if ([self.delegate respondsToSelector:@selector(privateMessageComposeControllerDidCancel:)]) {
        [self.delegate privateMessageComposeControllerDidCancel:self];
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
    // TODO
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
    self.recipient = regardingMessage.from.username;
    if ([regardingMessage.subject hasPrefix:@"Re: "]) {
        self.subject = regardingMessage.subject;
    } else {
        self.subject = [NSString stringWithFormat:@"Re: %@", regardingMessage.subject];
    }
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
    // TODO show post icon selector
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.toField.textField.text = self.recipient;
    self.subjectField.textField.text = self.subject;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    // TODO set post icon
}

@end
