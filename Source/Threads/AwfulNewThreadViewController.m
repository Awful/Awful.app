//  AwfulNewThreadViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewThreadViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumTweaks.h"
#import "AwfulForumsClient.h"
#import "AwfulNewThreadFieldView.h"
#import "AwfulPostIconPickerController.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagLoader.h"
#import "UINavigationItem+TwoLineTitle.h"

@interface AwfulNewThreadViewController () <AwfulPostIconPickerControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) AwfulNewThreadFieldView *fieldView;
@property (strong, nonatomic) AwfulPostIconPickerController *postIconPicker;
@property (strong, nonatomic) AwfulThreadTag *threadTag;
@property (strong, nonatomic) AwfulThreadTag *secondaryThreadTag;

@end

@implementation AwfulNewThreadViewController
{
    NSString *_secondaryIconKey;
    NSArray *_availableThreadTags;
    NSArray *_availableSecondaryThreadTags;
}

- (id)initWithForum:(AwfulForum *)forum
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _forum = forum;
    self.title = DefaultTitle;
    self.submitButtonItem.title = @"Post";
    self.restorationClass = self.class;
	[self updateTweaks];
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
        [_postIconPicker reloadData];
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
        image = [[AwfulThreadTagLoader loader] imageNamed:self.threadTag.imageName];
    } else {
        image = [[AwfulThreadTagLoader loader] unsetThreadTagImage];
    }
    [self.fieldView.threadTagButton setImage:image forState:UIControlStateNormal];
    if (self.secondaryThreadTag) {
        AwfulThreadTag *tag = self.secondaryThreadTag;
        image = [[AwfulThreadTagLoader loader] imageNamed:tag.imageName];
    } else {
        image = nil;
    }
    self.fieldView.threadTagButton.secondaryTagImage = image;
}

- (void)didTapThreadTagButton:(UIButton *)button
{
    if (self.threadTag) {
        self.postIconPicker.selectedIndex = [_availableThreadTags indexOfObject:self.threadTag] + 1;
    } else {
        self.postIconPicker.selectedIndex = -1;
    }
    if (self.secondaryThreadTag) {
        self.postIconPicker.secondarySelectedIndex = [_availableSecondaryThreadTags indexOfObject:self.secondaryThreadTag];
    } else if (_availableSecondaryThreadTags.count > 0) {
        self.postIconPicker.secondarySelectedIndex = -1;
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
    AwfulAlertView *alert = [AwfulAlertView new];
    alert.title = @"Incoming Forums Superstar";
    alert.message = [NSString stringWithFormat:@"You're making a new thread in %@. Will it be "
                     "funny, informative, or interesting on any level?", self.forum.name];
    [alert addCancelButtonWithTitle:@"Nope" block:^{ handler(NO); }];
    [alert addButtonWithTitle:self.submitButtonItem.title block:^{ handler(YES); }];
    [alert show];
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

#pragma mark - AwfulPostIconPickerControllerDelegate

- (NSInteger)numberOfIconsInPostIconPicker:(AwfulPostIconPickerController *)picker
{
    // +1 for the empty thread tag.
    return _availableThreadTags.count + 1;
}

- (NSInteger)numberOfSecondaryIconsInPostIconPicker:(AwfulPostIconPickerController *)picker
{
    return _availableSecondaryThreadTags.count;
}

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker postIconAtIndex:(NSInteger)index
{
    if (index == 0) {
        return [[AwfulThreadTagLoader loader] emptyThreadTagImage];
    } else {
        AwfulThreadTag *tag = _availableThreadTags[index - 1];
        return [[AwfulThreadTagLoader loader] imageNamed:tag.imageName];
    }
}

- (NSString *)postIconPicker:(AwfulPostIconPickerController *)picker nameOfSecondaryIconAtIndex:(NSInteger)index
{
    // TODO grab new style from thread table view controller
    AwfulThreadTag *tag = _availableSecondaryThreadTags[index];
    return tag.imageName;
}

- (void)postIconPicker:(AwfulPostIconPickerController *)picker didSelectIconAtIndex:(NSInteger)index
{
    // On iPad we update immediately and there is no "cancel". On iPhone we update only on successful completion.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (index == 0) {
            self.threadTag = nil;
        } else {
            self.threadTag = _availableThreadTags[index - 1];
        }
    }
}

- (void)postIconPicker:(AwfulPostIconPickerController *)picker didSelectSecondaryIconAtIndex:(NSInteger)index
{
    // On iPad we update immediately and there is no "cancel". On iPhone we update only on successful completion.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.secondaryThreadTag = _availableSecondaryThreadTags[index];
    }
}

- (void)postIconPickerDidComplete:(AwfulPostIconPickerController *)picker
{
    if (picker.selectedIndex == 0) {
        self.threadTag = nil;
    } else {
        self.threadTag = _availableThreadTags[picker.selectedIndex - 1];
    }
    if (_availableSecondaryThreadTags.count > 0) {
        self.secondaryThreadTag = _availableSecondaryThreadTags[picker.secondarySelectedIndex];
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
    [super decodeRestorableStateWithCoder:coder];
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
}

static NSString * const ForumIDKey = @"AwfulForumID";
static NSString * const SubjectKey = @"AwfulSubject";
static NSString * const ThreadTagImageNameKey = @"AwfulThreadTagImageName";
static NSString * const SecondaryThreadTagImageNameKey = @"AwfulSecondaryThreadTagImageName";

@end
