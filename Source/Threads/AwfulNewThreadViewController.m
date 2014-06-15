//  AwfulNewThreadViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewThreadViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumTweaks.h"
#import "AwfulForumsClient.h"
#import "AwfulNewThreadFieldView.h"
#import "AwfulThreadPreviewViewController.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagLoader.h"
#import "AwfulThreadTagPickerController.h"
#import "UINavigationItem+TwoLineTitle.h"

@interface AwfulNewThreadViewController () <AwfulThreadTagPickerControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) AwfulNewThreadFieldView *fieldView;
@property (strong, nonatomic) AwfulThreadTagPickerController *threadTagPicker;
@property (strong, nonatomic) AwfulThreadTag *threadTag;
@property (strong, nonatomic) AwfulThreadTag *secondaryThreadTag;

@property (copy, nonatomic) void (^onAppearBlock)(void);

@end

@implementation AwfulNewThreadViewController
{
    NSString *_secondaryIconKey;
    NSArray *_availableThreadTags;
    NSArray *_availableSecondaryThreadTags;
}

- (id)initWithForum:(AwfulForum *)forum
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _forum = forum;
        self.title = DefaultTitle;
        self.submitButtonItem.title = @"Preview";
        self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
        self.restorationClass = self.class;
        [self updateTweaks];
    }
    return self;
}

static NSString * const DefaultTitle = @"New Thread";

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.navigationItem.titleLabel.text = title;
}

- (void)setThreadTag:(AwfulThreadTag *)threadTag
{
    _threadTag = threadTag;
    [self updateThreadTagButtonImage];
}

- (void)setSecondaryThreadTag:(AwfulThreadTag *)secondaryThreadTag
{
    _secondaryThreadTag = secondaryThreadTag;
    [self updateThreadTagButtonImage];
}

- (AwfulTheme *)theme
{
    return [AwfulTheme currentThemeForForum:self.forum];
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
    [[AwfulForumsClient client] listAvailablePostIconsForForumWithID:self.forum.forumID andThen:^(NSError *error, AwfulForm *form) {
        _availableThreadTags = [form.threadTags copy];
        _availableSecondaryThreadTags = [form.secondaryThreadTags copy];
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
	AwfulForumTweaks *tweaks = [AwfulForumTweaks tweaksForForumId:self.forum.forumID];
	
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
        AwfulThreadTag *tag = self.secondaryThreadTag;
        image = [AwfulThreadTagLoader imageNamed:tag.imageName];
    } else {
        image = nil;
    }
    self.fieldView.threadTagButton.secondaryTagImage = image;
}

- (void)didTapThreadTagButton:(UIButton *)button
{
    // TODO better handle waiting for the available thread tags to download
    if (!_availableThreadTags) return;
    
    NSString *selectedImageName = self.threadTag.imageName ?: AwfulThreadTagLoaderEmptyThreadTagImageName;
    [self.threadTagPicker selectImageName:selectedImageName];
    if (_availableSecondaryThreadTags.count > 0) {
        NSString *selectedSecondaryImageName = self.secondaryThreadTag.imageName ?: [_availableSecondaryThreadTags[0] imageName];
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
    if (!_availableThreadTags) return nil;
    
    NSMutableArray *imageNames = [NSMutableArray arrayWithObject:AwfulThreadTagLoaderEmptyThreadTagImageName];
    [imageNames addObjectsFromArray:[_availableThreadTags valueForKey:@"imageName"]];
    NSArray *secondaryImageNames = [_availableSecondaryThreadTags valueForKey:@"imageName"];
    _threadTagPicker = [[AwfulThreadTagPickerController alloc] initWithImageNames:imageNames secondaryImageNames:secondaryImageNames];
    _threadTagPicker.delegate = self;
    _threadTagPicker.title = @"Choose Thread Tag";
    if (_availableSecondaryThreadTags.count > 0) {
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
                                      threadTag:_threadTag
                                   secondaryTag:_secondaryThreadTag
                            secondaryTagFormKey:_secondaryIconKey
                                         BBcode:composition
                                        andThen:^(NSError *error, AwfulThread *thread)
    {
        __typeof__(self) self = weakSelf;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK" completion:^{
                completionHandler(NO);
            }];
        } else {
            self->_thread = thread;
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
        [_availableThreadTags enumerateObjectsUsingBlock:^(AwfulThreadTag *threadTag, NSUInteger i, BOOL *stop) {
            if ([threadTag.imageName isEqualToString:imageName]) {
                self.threadTag = threadTag;
                *stop = YES;
            }
        }];
    }
    if (_availableSecondaryThreadTags.count == 0) {
        [picker dismiss];
        [self focusInitialFirstResponder];
    }
}

- (void)threadTagPicker:(AwfulThreadTagPickerController *)picker didSelectSecondaryImageName:(NSString *)secondaryImageName
{
    [_availableSecondaryThreadTags enumerateObjectsUsingBlock:^(AwfulThreadTag *secondaryThreadTag, NSUInteger i, BOOL *stop) {
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
    AwfulForum *forum = [AwfulForum fetchOrInsertForumInManagedObjectContext:[AwfulAppDelegate instance].managedObjectContext
                                                                      withID:[coder decodeObjectForKey:ForumIDKey]];
    AwfulNewThreadViewController *newThreadViewController = [[AwfulNewThreadViewController alloc] initWithForum:forum];
    newThreadViewController.restorationIdentifier = identifierComponents.lastObject;
    return newThreadViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.forum.forumID forKey:ForumIDKey];
    [coder encodeObject:self.fieldView.subjectField.textField.text forKey:SubjectKey];
    [coder encodeObject:self.threadTag.imageName forKey:ThreadTagImageNameKey];
    [coder encodeObject:self.secondaryThreadTag.imageName forKey:SecondaryThreadTagImageNameKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    self.fieldView.subjectField.textField.text = [coder decodeObjectForKey:SubjectKey];
    NSString *threadTagImageName = [coder decodeObjectForKey:ThreadTagImageNameKey];
    if (threadTagImageName) {
        self.threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:nil
                                                                  imageName:threadTagImageName
                                                     inManagedObjectContext:self.forum.managedObjectContext];
    }
    NSString *secondaryThreadTagImageName = [coder decodeObjectForKey:SecondaryThreadTagImageNameKey];
    if (secondaryThreadTagImageName) {
        self.secondaryThreadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:nil
                                                                           imageName:secondaryThreadTagImageName
                                                              inManagedObjectContext:self.forum.managedObjectContext];
    }
    
    [super decodeRestorableStateWithCoder:coder];
}

static NSString * const ForumIDKey = @"AwfulForumID";
static NSString * const SubjectKey = @"AwfulSubject";
static NSString * const ThreadTagImageNameKey = @"AwfulThreadTagImageName";
static NSString * const SecondaryThreadTagImageNameKey = @"AwfulSecondaryThreadTagImageName";

@end
