//  AwfulPrivateMessageComposeViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulComposeField.h"
#import "AwfulHTTPClient.h"
#import "AwfulPostIconPickerController.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagButton.h"
#import "AwfulThreadTags.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface AwfulPrivateMessageComposeViewController () <AwfulPostIconPickerControllerDelegate,
                                                        UITextFieldDelegate>

@property (copy, nonatomic) NSString *recipient;
@property (copy, nonatomic) NSString *subject;
@property (copy, nonatomic) NSString *messageBody;
@property (nonatomic) AwfulPrivateMessage *regardingMessage;
@property (nonatomic) AwfulPrivateMessage *forwardedMessage;

@property (copy, nonatomic) NSArray *availablePostIcons;
@property (nonatomic) AwfulThreadTag *postIcon;

@property (weak, nonatomic) UIView *topView;
@property (weak, nonatomic) AwfulThreadTagButton *postIconButton;
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
    id op = [[AwfulHTTPClient client] sendPrivateMessageTo:self.recipient ?: @""
                                                   subject:self.subject ?: @""
                                                      icon:self.postIcon.composeID
                                                      text:messageBody ?: @""
                                    asReplyToMessageWithID:self.regardingMessage.messageID
                                forwardedFromMessageWithID:self.forwardedMessage.messageID
                                                   andThen:^(NSError *error)
    {
        if (error) {
            [SVProgressHUD dismiss];
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"
                               completion:^
            {
                [self setTextFieldsAndViewUserInteractionEnabled:YES];
                [self.textView becomeFirstResponder];
            }];
            return;
        }
        [SVProgressHUD showSuccessWithStatus:@"Sent"];
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
    self.networkOperation = op;
}

- (void)cancel
{
    [super cancel];
    [self.networkOperation cancel];
    if ([SVProgressHUD isVisible]) {
        [SVProgressHUD dismiss];
        [self setTextFieldsAndViewUserInteractionEnabled:YES];
        [self.textView becomeFirstResponder];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
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

- (void)setPostIcon:(AwfulThreadTag *)postIcon
{
    if (_postIcon == postIcon) return;
    _postIcon = postIcon;
    UIImage *image;
    if (postIcon) {
        image = [[AwfulThreadTags sharedThreadTags] threadTagNamed:postIcon.imageName];
    } else {
        image = [UIImage imageNamed:[AwfulThreadTag emptyPrivateMessageTagImageName]];
    }
    [self.postIconButton setImage:image forState:UIControlStateNormal];
}

- (void)setMessageBody:(NSString *)messageBody
{
    if (_messageBody == messageBody) return;
    _messageBody = [messageBody copy];
    self.textView.text = _messageBody;
    self.textView.selectedRange = NSMakeRange(0, 0);
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
        CGPoint topOffset = CGPointMake(0, -self.textView.contentInset.top);
        if ([self.recipient length] == 0) {
            [self.toField.textField becomeFirstResponder];
            self.textView.contentOffset = topOffset;
        } else if ([self.subject length] == 0) {
            [self.subjectField.textField becomeFirstResponder];
            self.textView.contentOffset = topOffset;
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
    [super loadView];
    const CGFloat fieldHeight = 88;
    self.textView.textContainerInset = UIEdgeInsetsMake(fieldHeight + 5, 0, 0, 0);
    
    UIView *topView = [UIView new];
    topView.frame = CGRectMake(0, 0, CGRectGetWidth(self.textView.frame), fieldHeight);
    topView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                UIViewAutoresizingFlexibleBottomMargin);
    [self.textView addSubview:topView];
    self.topView = topView;
    
    CGRect postIconFrame, fieldsFrame;
    CGRectDivide(topView.bounds, &postIconFrame, &fieldsFrame, 54, CGRectMinXEdge);
    postIconFrame.size.height -= 1;
    AwfulThreadTagButton *postIconButton = [[AwfulThreadTagButton alloc]
                                            initWithFrame:postIconFrame];
    postIconButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
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
    toField.label.text = @"To:";
    toField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    toField.textField.keyboardAppearance = self.textView.keyboardAppearance;
    toField.textField.delegate = self;
    toField.textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    toField.textField.autocorrectionType = UITextAutocorrectionTypeNo;
    [toField.textField addTarget:self action:@selector(toFieldDidChange:)
                forControlEvents:UIControlEventEditingDidEnd];
    [toField.textField addTarget:self action:@selector(updateSendButton)
                forControlEvents:UIControlEventEditingChanged];
    [topView addSubview:toField];
    self.toField = toField;
    
    AwfulComposeField *subjectField = [[AwfulComposeField alloc] initWithFrame:subjectFrame];
    subjectField.label.text = @"Subject:";
    subjectField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    subjectField.textField.keyboardAppearance = self.textView.keyboardAppearance;
    subjectField.textField.delegate = self;
    [subjectField.textField addTarget:self action:@selector(subjectFieldDidChange:)
                     forControlEvents:UIControlEventEditingDidEnd];
    [subjectField.textField addTarget:self action:@selector(updateTitleWithSubjectField:)
                     forControlEvents:UIControlEventEditingChanged];
    [subjectField.textField addTarget:self action:@selector(updateSendButton)
                     forControlEvents:UIControlEventEditingChanged];
    [topView addSubview:subjectField];
    self.subjectField = subjectField;
}

- (void)didTapPostIcon
{
    if (!self.postIconPicker) {
        self.postIconPicker = [[AwfulPostIconPickerController alloc] initWithDelegate:self];
    }
    if (self.postIcon) {
        NSUInteger index = [self.availablePostIcons indexOfObject:self.postIcon];
        self.postIconPicker.selectedIndex = index + 1;
    } else {
        self.postIconPicker.selectedIndex = 0;
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.postIconPicker showFromRect:self.postIconButton.frame
                                   inView:self.postIconButton.superview];
    } else {
        [self presentViewController:[self.postIconPicker enclosingNavigationController]
                           animated:YES
                         completion:nil];
    }
}

- (void)toFieldDidChange:(UITextField *)toField
{
    self.recipient = toField.text;
}

- (void)updateSendButton
{
    NSString *to = self.toField.textField.text;
    NSString *subject = self.subjectField.textField.text;
    NSString *body = self.textView.text;
    self.sendButton.enabled = [to length] > 0 && [subject length] > 0 && [body length] > 0;
}

- (void)subjectFieldDidChange:(UITextField *)subjectField
{
    self.subject = subjectField.text;
}

- (void)updateTitleWithSubjectField:(UITextField *)subjectField
{
    if ([subjectField.text length] > 0) {
        self.title = subjectField.text;
    } else {
        self.title = @"Private Message";
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.toField.textField.text = self.recipient;
    self.subjectField.textField.text = self.subject;
    [self updateSendButton];
    [self updateTitleWithSubjectField:self.subjectField.textField];
    UIImage *emptyImage = [UIImage imageNamed:[AwfulThreadTag emptyPrivateMessageTagImageName]];
    [self.postIconButton setImage:emptyImage forState:UIControlStateNormal];
    self.topView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1];
    self.postIconButton.backgroundColor = [UIColor whiteColor];
    self.toField.backgroundColor = [UIColor whiteColor];
    self.toField.label.textColor = [UIColor grayColor];
    self.toField.label.backgroundColor = [UIColor whiteColor];
    self.toField.textField.textColor = [UIColor blackColor];
    self.subjectField.backgroundColor = [UIColor whiteColor];
    self.subjectField.label.textColor = [UIColor grayColor];
    self.subjectField.label.backgroundColor = [UIColor whiteColor];
    self.subjectField.textField.textColor = [UIColor blackColor];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateSendButton];
    [self updateTitleWithSubjectField:self.subjectField.textField];
    [[AwfulHTTPClient client] listAvailablePrivateMessagePostIconsAndThen:^(NSError *error, NSArray *postIcons) {
        self.availablePostIcons = postIcons;
        [self.postIconPicker reloadData];
    }];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
                                         duration:(NSTimeInterval)duration
{
    [self.postIconPicker showFromRect:self.postIconButton.frame
                               inView:self.postIconButton.superview];
}

#pragma mark - AwfulPostIconPickerControllerDelegate

- (NSInteger)numberOfIconsInPostIconPicker:(AwfulPostIconPickerController *)picker
{
    return [self.availablePostIcons count] + 1;
}

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker postIconAtIndex:(NSInteger)index
{
    if (index == 0) {
        return [UIImage imageNamed:[AwfulThreadTag emptyPrivateMessageTagImageName]];
    }
    index -= 1;
    NSString *iconName = [self.availablePostIcons[index] imageName];
    // TODO handle downloading new thread tags
    return [[AwfulThreadTags sharedThreadTags] threadTagNamed:iconName];
}

- (void)postIconPickerDidComplete:(AwfulPostIconPickerController *)picker
{
    if (picker.selectedIndex == 0) {
        [self setPostIcon:nil];
    } else {
        self.postIcon = self.availablePostIcons[picker.selectedIndex - 1];
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
            self.postIcon = self.availablePostIcons[index - 1];
        }
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    // For reasons passing my understanding, it is impossible to nil out the text *field*'s input
    // accessory view. However, nil-ing out the text *view*'s input accessory view works great!
    self.textView.inputAccessoryView = nil;
    return YES;
}

#pragma mark - UITextViewDelegate

- (void)textViewDidChange:(UITextView *)textView
{
    [self updateSendButton];
}

#pragma mark State preservation and restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.recipient forKey:RecipientKey];
    [coder encodeObject:self.subject forKey:SubjectKey];
    [coder encodeObject:self.postIcon forKey:PostIconKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.recipient = [coder decodeObjectForKey:RecipientKey];
    self.subject = [coder decodeObjectForKey:SubjectKey];
    self.postIcon = [coder decodeObjectForKey:PostIconKey];
}

static NSString * const RecipientKey = @"AwfulRecipient";
static NSString * const SubjectKey = @"AwfulSubject";
static NSString * const PostIconKey = @"AwfulPostIcon";

@end
