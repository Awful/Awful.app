//
//  AwfulThreadComposeViewController.m
//  Awful
//
//  Created by Nolan Waite on 2013-05-18.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulThreadComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulComposeField.h"
#import "AwfulHTTPClient.h"
#import "AwfulPostIconPickerController.h"
#import "AwfulTheme.h"
#import "AwfulThreadTags.h"
#import "SVProgressHUD.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulThreadComposeViewController () <AwfulPostIconPickerControllerDelegate>

@property (nonatomic) AwfulForum *forum;
@property (nonatomic) UIView *topView;

@property (copy, nonatomic) NSString *postIcon;
@property (nonatomic) UIButton *postIconButton;
@property (nonatomic) AwfulPostIconPickerController *postIconPicker;
@property (copy, nonatomic) NSDictionary *availablePostIcons;
@property (copy, nonatomic) NSArray *availablePostIconIDs;

@property (copy, nonatomic) NSString *subject;
@property (nonatomic) AwfulComposeField *subjectField;

@property (weak, nonatomic) NSOperation *networkOperation;

@end


@implementation AwfulThreadComposeViewController

- (id)initWithForum:(AwfulForum *)forum
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    self.forum = forum;
    [self resetTitle];
    self.sendButton.title = @"Post";
    self.sendButton.target = self;
    self.sendButton.action = @selector(didTapPost);
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancel);
    return self;
}

- (void)resetTitle
{
    self.title = @"Post New Thread";
}

- (void)didTapPost
{
    if ([self.subject length] == 0) {
        [self.subjectField.textField becomeFirstResponder];
    } else {
        [self prepareToSendMessage];
    }
}

- (void)cancel
{
    [super cancel];
    [self.networkOperation cancel];
    self.networkOperation = nil;
    if ([SVProgressHUD isVisible]) {
        [SVProgressHUD dismiss];
        [self setTextFieldAndViewUserInteractionEnabled:YES];
        [self.textView becomeFirstResponder];
    } else {
        [self.delegate threadComposeControllerDidCancel:self];
    }
}

- (void)setTextFieldAndViewUserInteractionEnabled:(BOOL)enabled
{
    self.textView.userInteractionEnabled = enabled;
    self.subjectField.textField.userInteractionEnabled = enabled;
}

- (void)setPostIcon:(NSString *)postIcon
{
    if (_postIcon == postIcon) return;
    _postIcon = [postIcon copy];
    [self updatePostIconButtonImage];
}

- (void)updatePostIconButtonImage
{
    UIImage *image;
    if (self.postIcon) {
        image = [[AwfulThreadTags sharedThreadTags] threadTagNamed:self.postIcon];
    } else {
        image = [UIImage imageNamed:@"empty-pm-tag"];
    }
    [self.postIconButton setImage:image forState:UIControlStateNormal];
}

#pragma mark - AwfulComposeViewController

- (void)willTransitionToState:(AwfulComposeViewControllerState)state
{
    if (state == AwfulComposeViewControllerStateReady) {
        [self setTextFieldAndViewUserInteractionEnabled:YES];
        if ([self.subject length] == 0) {
            [self.subjectField.textField becomeFirstResponder];
            self.textView.contentOffset = CGPointMake(0, -self.textView.contentInset.top);
        } else {
            [self.textView becomeFirstResponder];
        }
    } else {
        [self setTextFieldAndViewUserInteractionEnabled:NO];
        [self.textView resignFirstResponder];
        [self.subjectField.textField resignFirstResponder];
    }
    
    if (state == AwfulComposeViewControllerStateUploadingImages) {
        [SVProgressHUD showWithStatus:@"Uploading images…"];
    } else if (state == AwfulComposeViewControllerStateSending) {
        [SVProgressHUD showWithStatus:@"Posting…"];
    } else if (state == AwfulComposeViewControllerStateError) {
        [SVProgressHUD dismiss];
    }
}

- (void)send:(NSString *)messageBody
{
    // TODO AwfulHTTPClient calls!
}

- (void)retheme
{
    [super retheme];
    AwfulTheme *theme = [AwfulTheme currentTheme];
    self.topView.backgroundColor = theme.messageComposeFieldSeparatorColor;
    self.postIconButton.backgroundColor = theme.messageComposeFieldBackgroundColor;
    self.subjectField.backgroundColor = theme.messageComposeFieldBackgroundColor;
    self.subjectField.label.textColor = theme.messageComposeFieldLabelColor;
    self.subjectField.label.backgroundColor = theme.messageComposeFieldBackgroundColor;
    self.subjectField.textField.textColor = theme.messageComposeFieldTextColor;
}

#pragma mark - UIViewController

- (void)loadView
{
    [super loadView];
    const CGFloat fieldHeight = 45;
    self.textView.contentInset = UIEdgeInsetsMake(fieldHeight, 0, 0, 0);
    
    self.topView = [UIView new];
    self.topView.frame = CGRectMake(0, -fieldHeight,
                                    CGRectGetWidth(self.textView.frame), fieldHeight);
    self.topView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleBottomMargin);
    [self.textView addSubview:self.topView];
    
    CGRect postIconFrame, subjectFieldFrame;
    CGRectDivide(self.topView.bounds, &postIconFrame, &subjectFieldFrame,
                 fieldHeight, CGRectMinXEdge);
    postIconFrame.size.height -= 1;
    self.postIconButton = [[UIButton alloc] initWithFrame:postIconFrame];
    self.postIconButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [self.postIconButton addTarget:self action:@selector(didTapPostIconButton)
                  forControlEvents:UIControlEventTouchUpInside];
    [self.topView addSubview:self.postIconButton];
    
    subjectFieldFrame.size.height -= 1;
    self.subjectField = [[AwfulComposeField alloc] initWithFrame:subjectFieldFrame];
    self.subjectField.label.text = @"Subject";
    self.subjectField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.subjectField.textField.keyboardAppearance = self.textView.keyboardAppearance;
    [self.subjectField.textField addTarget:self action:@selector(subjectFieldDidChange:)
                          forControlEvents:UIControlEventEditingChanged];
    [self.topView addSubview:self.subjectField];
}

- (void)didTapPostIconButton
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

- (void)subjectFieldDidChange:(UITextField *)subjectField
{
    self.subject = subjectField.text;
    [self enableSendButtonIfReady];
    if ([self.subject length] > 0) {
        self.title = self.subject;
    } else {
        [self resetTitle];
    }
}

- (void)enableSendButtonIfReady
{
    self.sendButton.enabled = [self.subject length] > 0;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updatePostIconButtonImage];
    [[AwfulHTTPClient client] listAvailablePostIconsForForumWithID:self.forum.forumID
     andThen:^(NSError *error, NSDictionary *postIcons, NSArray *postIconIDs) {
         NSMutableDictionary *postIconNames = [NSMutableDictionary new];
         for (id key in postIcons) {
             postIconNames[key] = [[postIcons[key] lastPathComponent] stringByDeletingPathExtension];
         }
         self.availablePostIcons = postIconNames;
         self.availablePostIconIDs = postIconIDs;
         [self.postIconPicker reloadData];
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self enableSendButtonIfReady];
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
    // +1 for the empty thread tag.
    return [self.availablePostIconIDs count] + 1;
}

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker postIconAtIndex:(NSInteger)index
{
    // -1 for the "empty thread" tag.
    index -= 1;
    if (index < 0) {
        // TODO empty *thread* tag
        return [UIImage imageNamed:@"empty-pm-tag"];
    } else {
        NSString *iconName = self.availablePostIcons[self.availablePostIconIDs[index]];
        return [[AwfulThreadTags sharedThreadTags] threadTagNamed:iconName];
    }
}

- (void)postIconPickerDidComplete:(AwfulPostIconPickerController *)picker
{
    if (picker.selectedIndex == 0) {
        self.postIcon = nil;
    } else {
        id selectedIconID = self.availablePostIconIDs[picker.selectedIndex - 1];
        self.postIcon = self.availablePostIcons[selectedIconID];
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
        index -= 1;
        if (index < 0) {
            self.postIcon = nil;
        } else {
            id selectedIconID = self.availablePostIconIDs[index];
            self.postIcon = self.availablePostIcons[selectedIconID];
        }
    }
}

@end
