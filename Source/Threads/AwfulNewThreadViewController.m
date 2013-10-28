//  AwfulNewThreadViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNewThreadViewController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulHTTPClient.h"
#import "AwfulNewThreadFieldView.h"
#import "AwfulPostIconPickerController.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTags.h"
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

- (void)dealloc
{
    NSLog(@"%s %@ is out!", __PRETTY_FUNCTION__, self);
}

- (id)initWithForum:(AwfulForum *)forum
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _forum = forum;
    self.title = DefaultTitle;
    self.submitButtonItem.title = @"Post";
    self.restorationClass = self.class;
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

- (void)loadView
{
    [super loadView];
    self.customView = self.fieldView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateThreadTagButtonImage];
    __weak __typeof__(self) weakSelf = self;
    [[AwfulHTTPClient client] listAvailablePostIconsForForumWithID:self.forum.forumID
                                                           andThen:^(NSError *error, NSArray *postIcons, NSArray *secondaryPostIcons, NSString *secondaryIconKey)
    {
        __typeof__(self) self = weakSelf;
        _availableThreadTags = [postIcons copy];
        _availableSecondaryThreadTags = [secondaryPostIcons copy];
        self.secondaryThreadTag = secondaryPostIcons.firstObject;
        _secondaryIconKey = [secondaryIconKey copy];
        [_postIconPicker reloadData];
    }];
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
        image = [[AwfulThreadTags sharedThreadTags] threadTagNamed:self.threadTag.imageName];
    } else {
        image = [UIImage imageNamed:[AwfulThreadTag emptyThreadTagImageName]];
    }
    [self.fieldView.threadTagButton setImage:image forState:UIControlStateNormal];
    if (self.secondaryThreadTag) {
        // TODO grab new style from AwfulThreadTableViewController
        AwfulThreadTag *tag = self.secondaryThreadTag;
        image = [[AwfulThreadTags sharedThreadTags] threadTagNamed:tag.imageName];
    } else {
        image = nil;
    }
    self.fieldView.threadTagButton.secondaryTagImage = image;
}

- (void)didTapThreadTagButton:(UIButton *)button
{
    if (self.threadTag) {
        self.postIconPicker.selectedIndex = [_availableThreadTags indexOfObject:self.threadTag];
    } else {
        self.postIconPicker.selectedIndex = 0;
    }
    if (self.secondaryThreadTag) {
        self.postIconPicker.secondarySelectedIndex = [_availableSecondaryThreadTags indexOfObject:self.secondaryThreadTag];
    } else if (_availableSecondaryThreadTags.count > 0) {
        self.postIconPicker.secondarySelectedIndex = 0;
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
    [[AwfulHTTPClient client] postThreadInForumWithID:self.forum.forumID
                                              subject:self.fieldView.subjectField.textField.text
                                                 icon:_threadTag.composeID
                                        secondaryIcon:_secondaryThreadTag.composeID
                                     secondaryIconKey:_secondaryIconKey
                                                 text:composition
                                              andThen:^(NSError *error, NSString *threadID)
    {
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK" completion:^{
                completionHandler(NO);
            }];
        } else {
            _thread = [AwfulThread firstOrNewThreadWithThreadID:threadID
                                         inManagedObjectContext:self.forum.managedObjectContext];
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
        return [UIImage imageNamed:[AwfulThreadTag emptyThreadTagImageName]];
    } else {
        AwfulThreadTag *tag = _availableThreadTags[index - 1];
        return [[AwfulThreadTags sharedThreadTags] threadTagNamed:tag.imageName];
    }
}

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker secondaryIconAtIndex:(NSInteger)index
{
    // TODO grab new style from thread table view controller
    AwfulThreadTag *tag = _availableSecondaryThreadTags[index];
    return [[AwfulThreadTags sharedThreadTags] threadTagNamed:tag.imageName];
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
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)postIconPickerDidCancel:(AwfulPostIconPickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
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
    [coder encodeObject:self.threadTag forKey:ThreadTagKey];
    [coder encodeObject:self.secondaryThreadTag forKey:SecondaryThreadTagKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.fieldView.subjectField.textField.text = [coder decodeObjectForKey:SubjectKey];
    self.threadTag = [coder decodeObjectForKey:ThreadTagKey];
    self.secondaryThreadTag = [coder decodeObjectForKey:SecondaryThreadTagKey];
}

static NSString * const ForumIDKey = @"AwfulForumID";
static NSString * const SubjectKey = @"AwfulSubject";
static NSString * const ThreadTagKey = @"AwfulThreadTag";
static NSString * const SecondaryThreadTagKey = @"AwfulSecondaryThreadTag";

@end
