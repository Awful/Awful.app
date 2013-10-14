//  AwfulThreadComposeViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulComposeField.h"
#import "AwfulHTTPClient.h"
#import "AwfulPostIconPickerController.h"
#import "AwfulSettings.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagButton.h"
#import "AwfulThreadTags.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <SVProgressHUD/SVProgressHUD.h>

@interface AwfulThreadComposeViewController () <AwfulPostIconPickerControllerDelegate, UITextFieldDelegate>

@property (nonatomic) AwfulForum *forum;
@property (nonatomic) UIView *topView;

@property (nonatomic) AwfulThreadTagButton *postIconButton;
@property (nonatomic) AwfulPostIconPickerController *postIconPicker;
@property (copy, nonatomic) NSArray *availablePostIcons;
@property (nonatomic) AwfulThreadTag *postIcon;
@property (copy, nonatomic) NSArray *availableSecondaryPostIcons;
@property (nonatomic) AwfulThreadTag *secondaryPostIcon;
@property (copy, nonatomic) NSString *secondaryIconKey;

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
    self.cancelButton.action = @selector(didTapCancel:);
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithForum:nil];
}

- (void)resetTitle
{
    self.title = @"Post New Thread";
}

- (void)didTapPost
{
    if ([self.subject length] == 0) {
        [self.subjectField.textField becomeFirstResponder];
    } else if ([AwfulSettings settings].confirmNewPosts) {
        AwfulAlertView *alert = [AwfulAlertView new];
        alert.title = @"Incoming Forums Superstar";
        alert.message = @"Am I making a post which is either funny, informative, or interesting "
                        @"on any level?";
        [alert addCancelButtonWithTitle:@"Nope" block:^{
            [self setTextFieldAndViewUserInteractionEnabled:YES];
            [self.textView becomeFirstResponder];
        }];
        [alert addButtonWithTitle:self.sendButton.title block:^{
            [self prepareToSendMessage];
        }];
        [alert show];
    } else {
        [self prepareToSendMessage];
    }
}

- (void)didTapCancel:(UIBarButtonItem *)cancelButtonItem
{
    if ([self.subject length] == 0 && [self.textView.text length] == 0) {
        return [self cancel];
    }
    AwfulActionSheet *sheet = [[AwfulActionSheet alloc] init];
    [sheet addDestructiveButtonWithTitle:@"Delete OP" block:^{
        [self cancel];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromBarButtonItem:cancelButtonItem animated:YES];
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
    if ([self.forum.forumID isEqualToString:@"219"]) {
        self.textView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.textView.autocorrectionType = UITextAutocorrectionTypeNo;
    }
}

- (void)setPostIcon:(AwfulThreadTag *)postIcon
{
    if (_postIcon == postIcon) return;
    _postIcon = postIcon;
    [self updatePostIconButtonImage];
}

- (void)setSecondaryPostIcon:(AwfulThreadTag *)secondaryPostIcon
{
    if (_secondaryPostIcon == secondaryPostIcon) return;
    _secondaryPostIcon = secondaryPostIcon;
    [self updatePostIconButtonImage];
}

- (void)updatePostIconButtonImage
{
    UIImage *image;
    if (self.postIcon) {
        image = [[AwfulThreadTags sharedThreadTags] threadTagNamed:self.postIcon.imageName];
    } else {
        image = [UIImage imageNamed:@"empty-thread-tag"];
    }
    [self.postIconButton setImage:image forState:UIControlStateNormal];
    if (self.secondaryPostIcon) {
        self.postIconButton.secondaryTagImage = [[AwfulThreadTags sharedThreadTags]
                                                 threadTagNamed:self.secondaryPostIcon.imageName];
    } else {
        self.postIconButton.secondaryTagImage = nil;
    }
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
    id op = [[AwfulHTTPClient client] postThreadInForumWithID:self.forum.forumID
                                                      subject:self.subject
                                                         icon:self.postIcon.composeID
                                                secondaryIcon:self.secondaryPostIcon.composeID
                                             secondaryIconKey:self.secondaryIconKey
                                                         text:messageBody
                                                      andThen:^(NSError *error, NSString *threadID)
    {
        if (error) {
            [SVProgressHUD dismiss];
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"
                               completion:^
            {
                [self setTextFieldAndViewUserInteractionEnabled:YES];
                [self.textView becomeFirstResponder];
            }];
            return;
        }
        [SVProgressHUD showSuccessWithStatus:@"Posted"];
        [self.delegate threadComposeController:self didPostThreadWithID:threadID];
    }];
    self.networkOperation = op;
}

#pragma mark - UIViewController

- (void)loadView
{
    [super loadView];
    const CGFloat fieldHeight = 45;
    self.textView.textContainerInset = UIEdgeInsetsMake(fieldHeight + 5, 0, 0, 0);
    
    self.topView = [UIView new];
    self.topView.frame = CGRectMake(0, 0, CGRectGetWidth(self.textView.frame), fieldHeight);
    self.topView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleBottomMargin);
    [self.textView addSubview:self.topView];
    
    CGRect postIconFrame, subjectFieldFrame;
    CGRectDivide(self.topView.bounds, &postIconFrame, &subjectFieldFrame,
                 fieldHeight, CGRectMinXEdge);
    postIconFrame.size.height -= 1;
    self.postIconButton = [[AwfulThreadTagButton alloc] initWithFrame:postIconFrame];
    self.postIconButton.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [self.postIconButton addTarget:self action:@selector(didTapPostIconButton)
                  forControlEvents:UIControlEventTouchUpInside];
    [self.topView addSubview:self.postIconButton];
    
    subjectFieldFrame.size.height -= 1;
    self.subjectField = [[AwfulComposeField alloc] initWithFrame:subjectFieldFrame];
    self.subjectField.label.text = @"Subject";
    self.subjectField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.subjectField.textField.keyboardAppearance = self.textView.keyboardAppearance;
    self.subjectField.textField.delegate = self;
    [self.subjectField.textField addTarget:self action:@selector(subjectFieldDidChange:)
                          forControlEvents:UIControlEventEditingChanged];
    [self.topView addSubview:self.subjectField];
    
    self.topView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1];
    self.postIconButton.backgroundColor = [UIColor whiteColor];
    self.subjectField.backgroundColor = [UIColor whiteColor];
    self.subjectField.label.textColor = [UIColor grayColor];
    self.subjectField.label.backgroundColor = [UIColor whiteColor];
}

- (void)didTapPostIconButton
{
    if (!self.postIconPicker) {
        self.postIconPicker = [[AwfulPostIconPickerController alloc] initWithDelegate:self];
        [self.postIconPicker reloadData];
    }
    if (self.postIcon) {
        NSUInteger index = [self.availablePostIcons indexOfObject:self.postIcon];
        self.postIconPicker.selectedIndex = index;
    } else {
        self.postIconPicker.selectedIndex = 0;
    }
    if (self.secondaryPostIcon) {
        NSUInteger index = [self.availableSecondaryPostIcons indexOfObject:self.secondaryPostIcon];
        self.postIconPicker.secondarySelectedIndex = index;
    } else if ([self.availableSecondaryPostIcons count] > 0) {
        self.postIconPicker.secondarySelectedIndex = 0;
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
    self.sendButton.enabled = [self.subject length] > 0 && [self.textView.text length] > 0;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updatePostIconButtonImage];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self subjectFieldDidChange:self.subjectField.textField];
    [self enableSendButtonIfReady];
    [[AwfulHTTPClient client] listAvailablePostIconsForForumWithID:self.forum.forumID
                                                           andThen:^(NSError *error,
                                                                     NSArray *postIcons,
                                                                     NSArray *secondaryPostIcons,
                                                                     NSString *secondaryIconKey)
     {
         self.availablePostIcons = postIcons;
         self.availableSecondaryPostIcons = secondaryPostIcons;
         self.secondaryPostIcon = self.availableSecondaryPostIcons[0];
         self.secondaryIconKey = secondaryIconKey;
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
    // +1 for the empty thread tag.
    return [self.availablePostIcons count] + 1;
}

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker postIconAtIndex:(NSInteger)index
{
    // -1 for the "empty thread" tag.
    index -= 1;
    if (index < 0) {
        return [UIImage imageNamed:[AwfulThreadTag emptyThreadTagImageName]];
    } else {
        NSString *iconName = [self.availablePostIcons[index] imageName];
        return [[AwfulThreadTags sharedThreadTags] threadTagNamed:iconName];
    }
}

- (NSInteger)numberOfSecondaryIconsInPostIconPicker:(AwfulPostIconPickerController *)picker
{
    return [self.availableSecondaryPostIcons count];
}

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker
       secondaryIconAtIndex:(NSInteger)index
{
    NSString *iconName = [self.availableSecondaryPostIcons[index] imageName];
    return [[AwfulThreadTags sharedThreadTags] threadTagNamed:iconName];
}

- (void)postIconPickerDidComplete:(AwfulPostIconPickerController *)picker
{
    NSInteger index = picker.selectedIndex - 1;
    if (index < 0) {
        self.postIcon = nil;
    } else {
        self.postIcon = self.availablePostIcons[index];
    }
    if ([self.availableSecondaryPostIcons count] > 0) {
        self.secondaryPostIcon = self.availableSecondaryPostIcons[picker.secondarySelectedIndex];
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
            self.postIcon = self.availablePostIcons[index];
        }
    }
}

- (void)postIconPicker:(AwfulPostIconPickerController *)picker
didSelectSecondaryIconAtIndex:(NSInteger)index
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.secondaryPostIcon = self.availableSecondaryPostIcons[index];
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
    [self enableSendButtonIfReady];
}

#pragma mark State preservation and restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.forum.forumID forKey:ForumIDKey];
    [coder encodeObject:self.subject forKey:SubjectKey];
    [coder encodeObject:self.postIcon forKey:PostIconKey];
    [coder encodeObject:self.secondaryPostIcon forKey:SecondaryPostIconKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    NSString *forumID = [coder decodeObjectForKey:ForumIDKey];
    self.forum = [AwfulForum fetchArbitraryInManagedObjectContext:AwfulAppDelegate.instance.managedObjectContext
                                          matchingPredicateFormat:@"forumID = %@", forumID];
    self.subject = [coder decodeObjectForKey:SubjectKey];
    self.postIcon = [coder decodeObjectForKey:PostIconKey];
    self.secondaryPostIcon = [coder decodeObjectForKey:SecondaryPostIconKey];
}

static NSString * const ForumIDKey = @"AwfulForumID";
static NSString * const SubjectKey = @"AwfulSubject";
static NSString * const PostIconKey = @"AwfulPostIcon";
static NSString * const SecondaryPostIconKey = @"AwfulSecondaryPostIcon";

@end
