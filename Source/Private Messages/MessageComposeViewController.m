//  MessageComposeViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "MessageComposeViewController.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulNewPrivateMessageFieldView.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagLoader.h"
#import "AwfulThreadTagPickerController.h"
#import "Awful-Swift.h"

@interface MessageComposeViewController () <AwfulThreadTagPickerControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) AwfulNewPrivateMessageFieldView *fieldView;

@property (strong, nonatomic) AwfulThreadTag *threadTag;
@property (strong, nonatomic) AwfulThreadTagPickerController *threadTagPicker;

@property (assign, nonatomic) BOOL updatingThreadTags;
@property (copy, nonatomic) NSArray *availableThreadTags;

@end

@implementation MessageComposeViewController

- (id)initWithRecipient:(AwfulUser *)recipient
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _recipient = recipient;
    }
    return self;
}

- (id)initWithRegardingMessage:(AwfulPrivateMessage *)regardingMessage initialContents:(NSString *)initialContents
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _regardingMessage = regardingMessage;
        _initialContents = [initialContents copy];
    }
    return self;
}

- (id)initWithForwardingMessage:(AwfulPrivateMessage *)forwardingMessage initialContents:(NSString *)initialContents
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _forwardingMessage = forwardingMessage;
        _initialContents = [initialContents copy];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.title = @"Private Message";
        self.submitButtonItem.title = @"Send";
        self.restorationClass = self.class;
    }
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
    
    NSDictionary *styleAttrs = @{NSForegroundColorAttributeName: self.theme[@"placeholderTextColor"]};
    NSAttributedString *toString = [[NSAttributedString alloc] initWithString:@"To" attributes:styleAttrs];
    self.fieldView.toField.textField.attributedPlaceholder = toString;
    NSAttributedString *subjectString = [[NSAttributedString alloc] initWithString:@"Subject" attributes:styleAttrs];
    self.fieldView.subjectField.textField.attributedPlaceholder = subjectString;
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
    
    [self updateAvailableThreadTagsIfNecessary];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateAvailableThreadTagsIfNecessary];
}

- (void)updateAvailableThreadTagsIfNecessary
{
    if (self.availableThreadTags.count > 0 || self.updatingThreadTags) return;
    self.updatingThreadTags = YES;
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] listAvailablePrivateMessageThreadTagsAndThen:^(NSError *error, NSArray *threadTags) {
        __typeof__(self) self = weakSelf;
        self.availableThreadTags = threadTags;
        self.updatingThreadTags = NO;
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
    if (self.threadTag.imageName) {
        image = [AwfulThreadTagLoader imageNamed:self.threadTag.imageName];
    } else {
        image = [AwfulThreadTagLoader unsetThreadTagImage];
    }
    [self.fieldView.threadTagButton setImage:image forState:UIControlStateNormal];
}

- (void)didTapThreadTagButton:(AwfulThreadTagButton *)button
{
    // TODO better handle waiting for available thread tags to download.
    if (self.availableThreadTags.count == 0) return;
    
    NSString *selectedImageName = self.threadTag.imageName ?: AwfulThreadTagLoaderEmptyPrivateMessageImageName;
    [self.threadTagPicker selectImageName:selectedImageName];
    [self.threadTagPicker presentFromView:button];
    
    // HACK: Calling -endEditing: once doesn't work if the To or Subject fields are selected. But twice works. I assume this is some weirdness from adding text fields as subviews to a text view.
    [self.view endEditing:YES];
    [self.view endEditing:YES];
}

- (AwfulThreadTagPickerController *)threadTagPicker
{
    if (_threadTagPicker) return _threadTagPicker;
    if (self.availableThreadTags.count == 0) return nil;
    
    NSMutableArray *imageNames = [NSMutableArray arrayWithObject:AwfulThreadTagLoaderEmptyPrivateMessageImageName];
    [imageNames addObjectsFromArray:[self.availableThreadTags valueForKey:@"imageName"]];
    _threadTagPicker = [[AwfulThreadTagPickerController alloc] initWithImageNames:imageNames secondaryImageNames:nil];
    _threadTagPicker.delegate = self;
    _threadTagPicker.navigationItem.leftBarButtonItem = _threadTagPicker.cancelButtonItem;
    return _threadTagPicker;
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
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] sendPrivateMessageTo:self.fieldView.toField.textField.text
                                         withSubject:self.fieldView.subjectField.textField.text
                                           threadTag:self.threadTag
                                              BBcode:composition
                                    asReplyToMessage:self.regardingMessage
                                forwardedFromMessage:self.forwardingMessage
                                             andThen:^(NSError *error)
    {
        __typeof__(self) self = weakSelf;
        if (error) {
            completionHandler(NO);
            [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
        } else {
            completionHandler(YES);
        }
    }];
}

#pragma mark - AwfulThreadTagPickerControllerDelegate

- (void)threadTagPicker:(AwfulThreadTagPickerController *)picker didSelectImageName:(NSString *)imageName
{
    if ([imageName isEqualToString:AwfulThreadTagLoaderEmptyPrivateMessageImageName]) {
        self.threadTag = nil;
    } else {
        [self.availableThreadTags enumerateObjectsUsingBlock:^(AwfulThreadTag *threadTag, NSUInteger i, BOOL *stop) {
            if ([threadTag.imageName isEqualToString:imageName]) {
                self.threadTag = threadTag;
                *stop = YES;
            }
        }];
    }
    [picker dismiss];
    [self focusInitialFirstResponder];
}

#pragma mark - UIViewControllerRestoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    NSString *recipientUserID = [coder decodeObjectForKey:RecipientUserIDKey];
    NSString *regardingMessageID = [coder decodeObjectForKey:RegardingMessageIDKey];
    NSString *forwardingMessageID = [coder decodeObjectForKey:ForwardingMessageIDKey];
    NSString *initialContents = [coder decodeObjectForKey:InitialContentsKey];
    NSManagedObjectContext *managedObjectContext = [AwfulAppDelegate instance].dataStack.managedObjectContext;
    MessageComposeViewController *newPrivateMessageViewController;
    if (recipientUserID) {
        AwfulUser *recipient = [AwfulUser firstOrNewUserWithUserID:recipientUserID
                                                          username:nil
                                            inManagedObjectContext:managedObjectContext];
        newPrivateMessageViewController = [[MessageComposeViewController alloc] initWithRecipient:recipient];
    } else if (regardingMessageID) {
        AwfulPrivateMessage *regardingMessage = [AwfulPrivateMessage fetchArbitraryInManagedObjectContext:managedObjectContext
                                                                                  matchingPredicateFormat:@"messageID = %@", regardingMessageID];
        newPrivateMessageViewController = [[MessageComposeViewController alloc] initWithRegardingMessage:regardingMessage
                                                                                                 initialContents:initialContents];
    } else if (forwardingMessageID) {
        AwfulPrivateMessage *forwardingMessage = [AwfulPrivateMessage fetchArbitraryInManagedObjectContext:managedObjectContext
                                                                                   matchingPredicateFormat:@"messageID = %@", forwardingMessageID];
        newPrivateMessageViewController = [[MessageComposeViewController alloc] initWithForwardingMessage:forwardingMessage
                                                                                                  initialContents:initialContents];
    } else {
        newPrivateMessageViewController = [[MessageComposeViewController alloc] initWithRecipient:nil];
    }
    newPrivateMessageViewController.restorationIdentifier = identifierComponents.lastObject;
    NSError *error;
    if (![managedObjectContext save:&error]) {
        NSLog(@"%s error saving managed object context: %@", __PRETTY_FUNCTION__, error);
    }
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
    
    [super decodeRestorableStateWithCoder:coder];
}

static NSString * const RecipientUserIDKey = @"AwfulRecipientUserID";
static NSString * const RegardingMessageIDKey = @"AwfulRegardingMessageID";
static NSString * const ForwardingMessageIDKey = @"AwfulForwardingMessageID";
static NSString * const InitialContentsKey = @"AwfulInitialContents";
static NSString * const ToKey = @"AwfulTo";
static NSString * const SubjectKey = @"AwfulSubject";
static NSString * const ThreadTagImageNameKey = @"AwfulThreadTagImageName";

@end
