//  ThreadComposeViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ThreadComposeViewController.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsClient.h"
#import "AwfulForumTweaks.h"
#import "AwfulNewThreadFieldView.h"
#import "AwfulThreadPreviewViewController.h"
#import "AwfulThreadTagLoader.h"
#import "AwfulThreadTagPickerController.h"
#import "UINavigationItem+TwoLineTitle.h"
#import "Awful-Swift.h"

@interface ThreadComposeViewController () <AwfulThreadTagPickerControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) Thread *thread;

@property (strong, nonatomic) AwfulNewThreadFieldView *fieldView;
@property (strong, nonatomic) AwfulThreadTagPickerController *threadTagPicker;
@property (strong, nonatomic) ThreadTag *threadTag;
@property (strong, nonatomic) ThreadTag *secondaryThreadTag;

@property (copy, nonatomic) void (^onAppearBlock)(void);

@property (copy, nonatomic) NSArray *availableThreadTags;
@property (copy, nonatomic) NSArray *availableSecondaryThreadTags;
@property (assign, nonatomic) BOOL updatingThreadTags;

@end

@implementation ThreadComposeViewController

- (instancetype)initWithForum:(Forum *)forum
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _forum = forum;
        self.title = DefaultTitle;
        self.submitButtonItem.title = @"Preview";
        self.restorationClass = self.class;
        [self updateTweaks];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSAssert(nil, @"Use -initWithForum: instead");
    return [self initWithForum:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSAssert(nil, @"Use -initWithForum: instead");
    return [self initWithForum:nil];
}

static NSString * const DefaultTitle = @"New Thread";

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.navigationItem.titleLabel.text = title;
}

- (void)setThreadTag:(ThreadTag *)threadTag
{
    _threadTag = threadTag;
    [self updateThreadTagButtonImage];
}

- (void)setSecondaryThreadTag:(ThreadTag *)secondaryThreadTag
{
    _secondaryThreadTag = secondaryThreadTag;
    [self updateThreadTagButtonImage];
}

- (Theme *)theme
{
    return [Theme currentThemeForForum:self.forum];
}

- (void)loadView
{
    [super loadView];
    self.customView = self.fieldView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateThreadTagButtonImage];
    [self updateAvailableThreadTagsIfNecessary];
}

- (void)updateAvailableThreadTagsIfNecessary
{
    if (self.availableThreadTags.count > 0 || self.updatingThreadTags) return;
    
    self.updatingThreadTags = YES;
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] listAvailablePostIconsForForumWithID:self.forum.forumID andThen:^(NSError *error, AwfulForm *form) {
        __typeof__(self) self = weakSelf;
        self.availableThreadTags = form.threadTags;
        self.availableSecondaryThreadTags = form.secondaryThreadTags;
        self.updatingThreadTags = NO;
    }];
}

- (void)themeDidChange
{
    [super themeDidChange];
    self.fieldView.subjectField.textField.textColor = self.textView.textColor;
    self.fieldView.subjectField.textField.keyboardAppearance = self.textView.keyboardAppearance;
    
    NSDictionary *styleAttrs = @{NSForegroundColorAttributeName: self.theme[@"placeholderTextColor"]};
    NSAttributedString *themedString = [[NSAttributedString alloc] initWithString:@"Subject" attributes:styleAttrs];
    self.fieldView.subjectField.textField.attributedPlaceholder = themedString;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateAvailableThreadTagsIfNecessary];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (self.onAppearBlock) {
        self.onAppearBlock();
        self.onAppearBlock = nil;
    }
}

- (void)updateTweaks
{
	AwfulForumTweaks *tweaks = [AwfulForumTweaks tweaksWithForumID:self.forum.forumID];
	
	//Apply autocorrection tweaks to subject field
	self.fieldView.subjectField.textField.autocapitalizationType = tweaks.autocapitalizationType;
    self.fieldView.subjectField.textField.autocorrectionType = tweaks.autocorrectionType;
    self.fieldView.subjectField.textField.spellCheckingType = tweaks.spellCheckingType;
	
	//Apply autocorrection tweaks to main text view
	self.textView.autocapitalizationType = tweaks.autocapitalizationType;
    self.textView.autocorrectionType = tweaks.autocorrectionType;
    self.textView.spellCheckingType = tweaks.spellCheckingType;
}

- (AwfulNewThreadFieldView *)fieldView
{
    if (_fieldView) return _fieldView;
    _fieldView = [[AwfulNewThreadFieldView alloc] initWithFrame:CGRectMake(0, 0, 0, 45)];
    _fieldView.subjectField.label.textColor = [UIColor grayColor];
    [_fieldView.threadTagButton addTarget:self
                                   action:@selector(didTapThreadTagButton:)
                         forControlEvents:UIControlEventTouchUpInside];
    [_fieldView.subjectField.textField addTarget:self
                                          action:@selector(subjectFieldDidChange:)
                                forControlEvents:UIControlEventEditingChanged];
    return _fieldView;
}

- (void)updateThreadTagButtonImage
{
    UIImage *image;
    if (self.threadTag) {
        image = [AwfulThreadTagLoader imageNamed:self.threadTag.imageName];
    } else {
        image = [AwfulThreadTagLoader unsetThreadTagImage];
    }
    [self.fieldView.threadTagButton setImage:image forState:UIControlStateNormal];
    if (self.secondaryThreadTag) {
        ThreadTag *tag = self.secondaryThreadTag;
        image = [AwfulThreadTagLoader imageNamed:tag.imageName];
    } else {
        image = nil;
    }
    self.fieldView.threadTagButton.secondaryTagImage = image;
}

- (void)didTapThreadTagButton:(UIButton *)button
{
    // TODO better handle waiting for the available thread tags to download
    if (self.availableThreadTags.count == 0) return;
    
    NSString *selectedImageName = self.threadTag.imageName ?: AwfulThreadTagLoaderEmptyThreadTagImageName;
    [self.threadTagPicker selectImageName:selectedImageName];
    if (self.availableSecondaryThreadTags.count > 0) {
        NSString *selectedSecondaryImageName = self.secondaryThreadTag.imageName ?: [self.availableSecondaryThreadTags[0] imageName];
        [self.threadTagPicker selectSecondaryImageName:selectedSecondaryImageName];
    }
    [self.threadTagPicker presentFromView:button];
    
    // HACK: Calling -endEditing: once doesn't work if the Subject field is selected. But twice works. I assume this is some weirdness from adding a text field as a subview to a text view.
    [self.view endEditing:YES];
    [self.view endEditing:YES];
}

- (AwfulThreadTagPickerController *)threadTagPicker
{
    if (_threadTagPicker) return _threadTagPicker;
    if (self.availableThreadTags.count == 0) return nil;
    
    NSMutableArray *imageNames = [NSMutableArray arrayWithObject:AwfulThreadTagLoaderEmptyThreadTagImageName];
    [imageNames addObjectsFromArray:[self.availableThreadTags valueForKey:@"imageName"]];
    NSArray *secondaryImageNames = [self.availableSecondaryThreadTags valueForKey:@"imageName"];
    _threadTagPicker = [[AwfulThreadTagPickerController alloc] initWithImageNames:imageNames secondaryImageNames:secondaryImageNames];
    _threadTagPicker.delegate = self;
    _threadTagPicker.title = @"Choose Thread Tag";
    if (self.availableSecondaryThreadTags.count > 0) {
        _threadTagPicker.navigationItem.rightBarButtonItem = _threadTagPicker.doneButtonItem;
    } else {
        _threadTagPicker.navigationItem.leftBarButtonItem = _threadTagPicker.cancelButtonItem;
    }
    return _threadTagPicker;
}

- (void)subjectFieldDidChange:(UITextField *)subjectTextField
{
    self.title = subjectTextField.text.length > 0 ? subjectTextField.text : DefaultTitle;
    [self updateSubmitButtonItem];
}

- (BOOL)canSubmitComposition
{
    return ([super canSubmitComposition] && self.fieldView.subjectField.textField.text.length > 0 && self.threadTag);
}

- (void)shouldSubmitHandler:(void(^)(BOOL ok))handler
{
    AwfulThreadPreviewViewController *preview = [[AwfulThreadPreviewViewController alloc] initWithForum:self.forum
                                                                                                subject:self.fieldView.subjectField.textField.text
                                                                                              threadTag:self.threadTag
                                                                                     secondaryThreadTag:self.secondaryThreadTag
                                                                                                 BBcode:self.textView.attributedText];
    preview.submitBlock = ^{ handler(YES); };
    self.onAppearBlock = ^{ handler(NO); };
    [self.navigationController pushViewController:preview animated:YES];
}

- (NSString *)submissionInProgressTitle
{
    return @"Posting…";
}

- (void)submitComposition:(NSString *)composition completionHandler:(void(^)(BOOL success))completionHandler
{
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] postThreadInForum:self.forum
                                      withSubject:self.fieldView.subjectField.textField.text
                                        threadTag:self.threadTag
                                     secondaryTag:self.secondaryThreadTag
                                           BBcode:composition
                                          andThen:^(NSError *error, Thread *thread)
    {
        __typeof__(self) self = weakSelf;
        if (error) {
            UIAlertController *alert = [[UIAlertController alloc] initWithTitle:@"Network Error" error:error handler:^(UIAlertAction *action) {
                completionHandler(NO);
            }];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            self.thread = thread;
            completionHandler(YES);
        }
    }];
}

#pragma mark - AwfulThreadTagPickerControllerDelegate

- (void)threadTagPicker:(AwfulThreadTagPickerController *)picker didSelectImageName:(NSString *)imageName
{
    if ([imageName isEqualToString:AwfulThreadTagLoaderEmptyThreadTagImageName]) {
        self.threadTag = nil;
    } else {
        [self.availableThreadTags enumerateObjectsUsingBlock:^(ThreadTag *threadTag, NSUInteger i, BOOL *stop) {
            if ([threadTag.imageName isEqualToString:imageName]) {
                self.threadTag = threadTag;
                *stop = YES;
            }
        }];
    }
    if (self.availableSecondaryThreadTags.count == 0) {
        [picker dismiss];
        [self focusInitialFirstResponder];
    }
}

- (void)threadTagPicker:(AwfulThreadTagPickerController *)picker didSelectSecondaryImageName:(NSString *)secondaryImageName
{
    [self.availableSecondaryThreadTags enumerateObjectsUsingBlock:^(ThreadTag *secondaryThreadTag, NSUInteger i, BOOL *stop) {
        if ([secondaryThreadTag.imageName isEqualToString:secondaryImageName]) {
            self.secondaryThreadTag = secondaryThreadTag;
            *stop = YES;
        }
    }];
}

- (void)threadTagPickerDidDismiss:(AwfulThreadTagPickerController *)picker
{
    [self focusInitialFirstResponder];
}

#pragma mark - State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    ForumKey *forumKey = [coder decodeObjectForKey:ForumKeyKey];
    if (!forumKey) {
        // AwfulObjectKey was introduced in Awful 3.2.
        NSString *forumID = [coder decodeObjectForKey:obsolete_ForumIDKey];
        forumKey = [[ForumKey alloc] initWithForumID:forumID];
    }
    Forum *forum = [Forum objectForKey:forumKey inManagedObjectContext:[AwfulAppDelegate instance].managedObjectContext];
    ThreadComposeViewController *newThreadViewController = [[ThreadComposeViewController alloc] initWithForum:forum];
    newThreadViewController.restorationIdentifier = identifierComponents.lastObject;
    return newThreadViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.forum.objectKey forKey:ForumKeyKey];
    [coder encodeObject:self.fieldView.subjectField.textField.text forKey:SubjectKey];
    [coder encodeObject:self.threadTag.objectKey forKey:ThreadTagKeyKey];
    [coder encodeObject:self.secondaryThreadTag.objectKey forKey:SecondaryThreadTagKeyKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
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
        self.threadTag = [ThreadTag objectForKey:tagKey inManagedObjectContext:self.forum.managedObjectContext];
    }
    ThreadTagKey *secondaryTagKey = [coder decodeObjectForKey:SecondaryThreadTagKeyKey];
    if (!secondaryTagKey) {
        NSString *secondaryTagImageName = [coder decodeObjectForKey:obsolete_SecondaryThreadTagImageNameKey];
        if (secondaryTagImageName) {
            secondaryTagKey = [[ThreadTagKey alloc] initWithImageName:secondaryTagImageName threadTagID:nil];
        }
    }
    if (secondaryTagKey) {
        self.secondaryThreadTag = [ThreadTag objectForKey:secondaryTagKey inManagedObjectContext:self.forum.managedObjectContext];
    }
    
    [super decodeRestorableStateWithCoder:coder];
}

static NSString * const ForumKeyKey = @"ForumKey";
static NSString * const obsolete_ForumIDKey = @"AwfulForumID";
static NSString * const SubjectKey = @"AwfulSubject";
static NSString * const ThreadTagKeyKey = @"ThreadTagKey";
static NSString * const obsolete_ThreadTagImageNameKey = @"AwfulThreadTagImageName";
static NSString * const SecondaryThreadTagKeyKey = @"SecondaryThreadTagKey";
static NSString * const obsolete_SecondaryThreadTagImageNameKey = @"AwfulSecondaryThreadTagImageName";

@end
