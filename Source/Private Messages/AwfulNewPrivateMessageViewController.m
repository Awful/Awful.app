//  AwfulNewPrivateMessageViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewPrivateMessageViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulHTTPClient.h"
#import "AwfulNewPrivateMessageFieldView.h"
#import "AwfulPostIconPickerController.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagLoader.h"
#import "AwfulUIKitAndFoundationCategories.h"

@interface AwfulNewPrivateMessageViewController () <AwfulPostIconPickerControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) AwfulNewPrivateMessageFieldView *fieldView;
@property (strong, nonatomic) AwfulThreadTag *threadTag;
@property (strong, nonatomic) AwfulPostIconPickerController *postIconPicker;

@end

@implementation AwfulNewPrivateMessageViewController
{
    NSArray *_availableThreadTags;
}

- (id)initWithRecipient:(AwfulUser *)recipient
{
    if (!(self = [self initWithNibName:nil bundle:nil])) return nil;
    _recipient = recipient;
    return self;
}

- (id)initWithRegardingMessage:(AwfulPrivateMessage *)regardingMessage initialContents:(NSString *)initialContents
{
    if (!(self = [self initWithNibName:nil bundle:nil])) return nil;
    _regardingMessage = regardingMessage;
    _initialContents = [initialContents copy];
    return self;
}

- (id)initWithForwardingMessage:(AwfulPrivateMessage *)forwardingMessage initialContents:(NSString *)initialContents
{
    if (!(self = [self initWithNibName:nil bundle:nil])) return nil;
    _forwardingMessage = forwardingMessage;
    _initialContents = [initialContents copy];
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.title = @"Private Message";
    self.submitButtonItem.title = @"Send";
    return self;
}

- (void)setThreadTag:(AwfulThreadTag *)threadTag
{
    _threadTag = threadTag;
    [self updateThreadTagButtonImage];
}

- (void)loadView
{
    [super loadView];
    self.customView = self.fieldView;
}

- (void)themeDidChange
{
    [super themeDidChange];
    self.fieldView.toField.textField.textColor = self.textView.textColor;
    self.fieldView.toField.textField.keyboardAppearance = self.textView.keyboardAppearance;
    self.fieldView.subjectField.textField.textColor = self.textView.textColor;
    self.fieldView.subjectField.textField.keyboardAppearance = self.textView.keyboardAppearance;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateThreadTagButtonImage];
    if (self.recipient) {
        if (self.fieldView.toField.textField.text.length == 0) {
            self.fieldView.toField.textField.text = self.recipient.username;
        }
    } else if (self.regardingMessage) {
        if (self.fieldView.toField.textField.text.length == 0) {
            self.fieldView.toField.textField.text = self.regardingMessage.from.username;
        }
        if (self.fieldView.subjectField.textField.text.length == 0) {
            NSString *subject = self.regardingMessage.subject;
            if (![subject hasPrefix:@"Re: "]) {
                subject = [NSString stringWithFormat:@"Re: %@", subject];
            }
            self.fieldView.subjectField.textField.text = subject;
        }
        if (self.textView.text.length == 0) {
            self.textView.text = self.initialContents;
        }
    } else if (self.forwardingMessage) {
        if (self.fieldView.subjectField.textField.text.length == 0) {
            self.fieldView.subjectField.textField.text = [NSString stringWithFormat:@"Fw: %@", self.forwardingMessage.subject];
        }
        if (self.textView.text.length == 0) {
            self.textView.text = self.initialContents;
        }
    }
    __weak __typeof__(self) weakSelf = self;
    [[AwfulHTTPClient client] listAvailablePrivateMessageThreadTagsAndThen:^(NSError *error, NSArray *threadTags) {
        __typeof__(self) self = weakSelf;
        self->_availableThreadTags = [threadTags copy];
        [_postIconPicker reloadData];
    }];
}

- (AwfulNewPrivateMessageFieldView *)fieldView
{
    if (_fieldView) return _fieldView;
    _fieldView = [[AwfulNewPrivateMessageFieldView alloc] initWithFrame:CGRectMake(0, 0, 0, 88)];
    _fieldView.toField.label.textColor = [UIColor grayColor];
    _fieldView.subjectField.label.textColor = [UIColor grayColor];
    [_fieldView.threadTagButton addTarget:self
                                   action:@selector(didTapThreadTagButton:)
                         forControlEvents:UIControlEventTouchUpInside];
    [_fieldView.toField.textField addTarget:self
                                     action:@selector(toFieldDidChange)
                           forControlEvents:UIControlEventEditingChanged];
    [_fieldView.subjectField.textField addTarget:self
                                          action:@selector(subjectFieldDidChange)
                                forControlEvents:UIControlEventEditingChanged];
    return _fieldView;
}

- (void)updateThreadTagButtonImage
{
    UIImage *image;
    if (self.threadTag) {
        image = [[AwfulThreadTagLoader loader] imageNamed:self.threadTag.imageName];
    } else {
        image = [[AwfulThreadTagLoader loader] emptyPrivateMessageImage];
    }
    [self.fieldView.threadTagButton setImage:image forState:UIControlStateNormal];
}

- (void)didTapThreadTagButton:(AwfulThreadTagButton *)button
{
    if (self.threadTag) {
        self.postIconPicker.selectedIndex = [_availableThreadTags indexOfObject:self.threadTag];
    } else {
        self.postIconPicker.selectedIndex = 0;
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.postIconPicker showFromRect:button.bounds inView:button];
    } else {
        [self presentViewController:[self.postIconPicker enclosingNavigationController] animated:YES completion:nil];
    }
}

- (AwfulPostIconPickerController *)postIconPicker
{
    if (_postIconPicker) return _postIconPicker;
    _postIconPicker = [[AwfulPostIconPickerController alloc] initWithDelegate:self];
    [_postIconPicker reloadData];
    return _postIconPicker;
}

- (void)toFieldDidChange
{
    [self updateSubmitButtonItem];
}

- (void)subjectFieldDidChange
{
    [self updateSubmitButtonItem];
}

- (BOOL)canSubmitComposition
{
    return ([super canSubmitComposition] &&
            self.fieldView.toField.textField.text.length > 0 &&
            self.fieldView.subjectField.textField.text.length > 0);
}

- (NSString *)submissionInProgressTitle
{
    return @"Sending…";
}

- (void)submitComposition:(NSString *)composition completionHandler:(void (^)(BOOL))completionHandler
{
    [[AwfulHTTPClient client] sendPrivateMessageTo:self.fieldView.toField.textField.text
                                       withSubject:self.fieldView.subjectField.textField.text
                                         threadTag:self.threadTag
                                            BBcode:composition
                                  asReplyToMessage:self.regardingMessage
                              forwardedFromMessage:self.forwardingMessage
                                           andThen:^(NSError *error)
    {
        if (error) {
            completionHandler(NO);
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            completionHandler(YES);
        }
    }];
}

#pragma mark - AwfulPostIconPickerControllerDelegate

- (NSInteger)numberOfIconsInPostIconPicker:(AwfulPostIconPickerController *)picker
{
    return _availableThreadTags.count + 1;
}

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker postIconAtIndex:(NSInteger)index
{
    if (index == 0) {
        return [[AwfulThreadTagLoader loader] emptyPrivateMessageImage];
    } else {
        AwfulThreadTag *tag = _availableThreadTags[index - 1];
        return [[AwfulThreadTagLoader loader] imageNamed:tag.imageName];
    }
}

- (void)postIconPicker:(AwfulPostIconPickerController *)picker didSelectIconAtIndex:(NSInteger)index
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (index == 0) {
            self.threadTag = nil;
        } else {
            self.threadTag = _availableThreadTags[index - 1];
        }
    }
}

- (void)postIconPickerDidComplete:(AwfulPostIconPickerController *)picker
{
    if (picker.selectedIndex == 0) {
        self.threadTag = nil;
    } else {
        self.threadTag = _availableThreadTags[picker.selectedIndex - 1];
    }
    [self dismissViewControllerAnimated:YES completion:^{
        [self focusInitialFirstResponder];
    }];
}

- (void)postIconPickerDidCancel:(AwfulPostIconPickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self focusInitialFirstResponder];
    }];
}

#pragma mark - UIViewControllerRestoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    NSString *recipientUserID = [coder decodeObjectForKey:RecipientUserIDKey];
    NSString *regardingMessageID = [coder decodeObjectForKey:RegardingMessageIDKey];
    NSString *forwardingMessageID = [coder decodeObjectForKey:ForwardingMessageIDKey];
    NSString *initialContents = [coder decodeObjectForKey:InitialContentsKey];
    NSManagedObjectContext *managedObjectContext = [AwfulAppDelegate instance].managedObjectContext;
    AwfulNewPrivateMessageViewController *newPrivateMessageViewController;
    if (recipientUserID) {
        AwfulUser *recipient = [AwfulUser firstOrNewUserWithUserID:recipientUserID
                                                          username:nil
                                            inManagedObjectContext:managedObjectContext];
        newPrivateMessageViewController = [[AwfulNewPrivateMessageViewController alloc] initWithRecipient:recipient];
    } else if (regardingMessageID) {
        AwfulPrivateMessage *regardingMessage = [AwfulPrivateMessage fetchArbitraryInManagedObjectContext:managedObjectContext
                                                                                  matchingPredicateFormat:@"messageID = %@", regardingMessageID];
        newPrivateMessageViewController = [[AwfulNewPrivateMessageViewController alloc] initWithRegardingMessage:regardingMessage
                                                                                                 initialContents:initialContents];
    } else if (forwardingMessageID) {
        AwfulPrivateMessage *forwardingMessage = [AwfulPrivateMessage fetchArbitraryInManagedObjectContext:managedObjectContext
                                                                                   matchingPredicateFormat:@"messageID = %@", forwardingMessageID];
        newPrivateMessageViewController = [[AwfulNewPrivateMessageViewController alloc] initWithForwardingMessage:forwardingMessage
                                                                                                  initialContents:initialContents];
    } else {
        newPrivateMessageViewController = [[AwfulNewPrivateMessageViewController alloc] initWithRecipient:nil];
    }
    newPrivateMessageViewController.restorationIdentifier = identifierComponents.lastObject;
    return newPrivateMessageViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.recipient.userID forKey:RecipientUserIDKey];
    [coder encodeObject:self.regardingMessage.messageID forKey:RegardingMessageIDKey];
    [coder encodeObject:self.forwardingMessage forKey:ForwardingMessageIDKey];
    [coder encodeObject:self.initialContents forKey:InitialContentsKey];
    [coder encodeObject:self.threadTag.imageName forKey:ThreadTagImageNameKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.fieldView.toField.textField.text = [coder decodeObjectForKey:ToKey];
    self.fieldView.subjectField.textField.text = [coder decodeObjectForKey:SubjectKey];
    NSString *threadTagImageName = [coder decodeObjectForKey:ThreadTagImageNameKey];
    if (threadTagImageName) {
        NSManagedObjectContext *managedObjectContext = (self.recipient.managedObjectContext ?:
                                                        self.regardingMessage.managedObjectContext ?:
                                                        self.forwardingMessage.managedObjectContext);
        self.threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:nil
                                                                  imageName:threadTagImageName
                                                     inManagedObjectContext:managedObjectContext];
    }
}

static NSString * const RecipientUserIDKey = @"AwfulRecipientUserID";
static NSString * const RegardingMessageIDKey = @"AwfulRegardingMessageID";
static NSString * const ForwardingMessageIDKey = @"AwfulForwardingMessageID";
static NSString * const InitialContentsKey = @"AwfulInitialContents";
static NSString * const ToKey = @"AwfulTo";
static NSString * const SubjectKey = @"AwfulSubject";
static NSString * const ThreadTagImageNameKey = @"AwfulThreadTagImageName";

@end
