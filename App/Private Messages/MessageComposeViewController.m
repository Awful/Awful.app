//  MessageComposeViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "MessageComposeViewController.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulThreadTagLoader.h"
#import "AwfulThreadTagPickerController.h"
#import "Awful-Swift.h"

@interface MessageComposeViewController () <AwfulThreadTagPickerControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) NewPrivateMessageFieldView *fieldView;

@property (strong, nonatomic) ThreadTag *threadTag;
@property (strong, nonatomic) AwfulThreadTagPickerController *threadTagPicker;

@property (assign, nonatomic) BOOL updatingThreadTags;
@property (copy, nonatomic) NSArray *availableThreadTags;

@end

@implementation MessageComposeViewController

- (instancetype)initWithRecipient:(User *)recipient
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _recipient = recipient;
    }
    return self;
}

- (instancetype)initWithRegardingMessage:(PrivateMessage *)regardingMessage initialContents:(NSString *)initialContents
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _regardingMessage = regardingMessage;
        _initialContents = [initialContents copy];
    }
    return self;
}

- (instancetype)initWithForwardingMessage:(PrivateMessage *)forwardingMessage initialContents:(NSString *)initialContents
{
    if ((self = [self initWithNibName:nil bundle:nil])) {
        _forwardingMessage = forwardingMessage;
        _initialContents = [initialContents copy];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.title = @"Private Message";
        self.submitButtonItem.title = @"Send";
        self.restorationClass = self.class;
    }
    return self;
}

- (void)setThreadTag:(ThreadTag *)threadTag
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

- (NewPrivateMessageFieldView *)fieldView
{
    if (_fieldView) return _fieldView;
    _fieldView = [[NewPrivateMessageFieldView alloc] initWithFrame:CGRectMake(0, 0, 0, 88)];
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

- (void)didTapThreadTagButton:(ThreadTagButton *)button
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
        [self.availableThreadTags enumerateObjectsUsingBlock:^(ThreadTag *threadTag, NSUInteger i, BOOL *stop) {
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
    // AwfulObjectKey was introduced in Awful 3.2.
    UserKey *recipientKey = [coder decodeObjectForKey:RecipientUserKeyKey];
    if (!recipientKey) {
        NSString *recipientUserID = [coder decodeObjectForKey:obsolete_RecipientUserIDKey];
        if (recipientUserID) {
            recipientKey = [[UserKey alloc] initWithUserID:recipientUserID username:nil];
        }
    }
    PrivateMessageKey *regardingKey = [coder decodeObjectForKey:RegardingMessageKeyKey];
    if (!regardingKey) {
        NSString *regardingMessageID = [coder decodeObjectForKey:obsolete_RegardingMessageIDKey];
        if (regardingMessageID) {
            regardingKey = [[PrivateMessageKey alloc] initWithMessageID:regardingMessageID];
        }
    }
    PrivateMessageKey *forwardingKey = [coder decodeObjectForKey:ForwardingMessageKeyKey];
    if (!forwardingKey) {
        NSString *forwardingMessageID = [coder decodeObjectForKey:obsolete_ForwardingMessageIDKey];
        if (forwardingMessageID) {
            forwardingKey = [[PrivateMessageKey alloc] initWithMessageID:forwardingMessageID];
        }
    }
    NSString *initialContents = [coder decodeObjectForKey:InitialContentsKey];
    NSManagedObjectContext *managedObjectContext = [AwfulAppDelegate instance].managedObjectContext;
    MessageComposeViewController *newPrivateMessageViewController;
    if (recipientKey) {
        User *recipient = [User objectForKey:recipientKey inManagedObjectContext:managedObjectContext];
        newPrivateMessageViewController = [[MessageComposeViewController alloc] initWithRecipient:recipient];
    } else if (regardingKey) {
        PrivateMessage *regardingMessage = [PrivateMessage objectForKey:regardingKey inManagedObjectContext:managedObjectContext];
        newPrivateMessageViewController = [[MessageComposeViewController alloc] initWithRegardingMessage:regardingMessage
                                                                                         initialContents:initialContents];
    } else if (forwardingKey) {
        PrivateMessage *forwardingMessage = [PrivateMessage objectForKey:forwardingKey inManagedObjectContext:managedObjectContext];
        newPrivateMessageViewController = [[MessageComposeViewController alloc] initWithForwardingMessage:forwardingMessage
                                                                                          initialContents:initialContents];
    } else {
        newPrivateMessageViewController = [[MessageComposeViewController alloc] initWithRecipient:nil];
    }
    newPrivateMessageViewController.restorationIdentifier = identifierComponents.lastObject;
    return newPrivateMessageViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.recipient.objectKey forKey:RecipientUserKeyKey];
    [coder encodeObject:self.regardingMessage.objectKey forKey:RegardingMessageKeyKey];
    [coder encodeObject:self.forwardingMessage.objectKey forKey:ForwardingMessageKeyKey];
    [coder encodeObject:self.initialContents forKey:InitialContentsKey];
    [coder encodeObject:self.threadTag.objectKey forKey:ThreadTagKeyKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    self.fieldView.toField.textField.text = [coder decodeObjectForKey:ToKey];
    self.fieldView.subjectField.textField.text = [coder decodeObjectForKey:SubjectKey];
    // AwfulObjectKey was introduced in Awful 3.2.
    ThreadTagKey *tagKey = [coder decodeObjectForKey:ThreadTagKeyKey];
    if (!tagKey) {
        NSString *threadTagImageName = [coder decodeObjectForKey:obsolete_ThreadTagImageNameKey];
        if (threadTagImageName) {
            tagKey = [[ThreadTagKey alloc] initWithImageName:threadTagImageName threadTagID:nil];
        }
    }
    if (tagKey) {
        NSManagedObjectContext *managedObjectContext = (self.recipient.managedObjectContext ?:
                                                        self.regardingMessage.managedObjectContext ?:
                                                        self.forwardingMessage.managedObjectContext);
        self.threadTag = [ThreadTag objectForKey:tagKey inManagedObjectContext:managedObjectContext];
    }
    
    [super decodeRestorableStateWithCoder:coder];
}

static NSString * const RecipientUserKeyKey = @"RecipientUserKey";
static NSString * const obsolete_RecipientUserIDKey = @"AwfulRecipientUserID";
static NSString * const RegardingMessageKeyKey = @"RegardingMessageKey";
static NSString * const obsolete_RegardingMessageIDKey = @"AwfulRegardingMessageID";
static NSString * const ForwardingMessageKeyKey = @"ForwardingMessageKey";
static NSString * const obsolete_ForwardingMessageIDKey = @"AwfulForwardingMessageID";
static NSString * const InitialContentsKey = @"AwfulInitialContents";
static NSString * const ToKey = @"AwfulTo";
static NSString * const SubjectKey = @"AwfulSubject";
static NSString * const ThreadTagKeyKey = @"ThreadTagKey";
static NSString * const obsolete_ThreadTagImageNameKey = @"AwfulThreadTagImageName";

@end
