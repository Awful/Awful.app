//  ComposeTextViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ComposeTextViewController.h"
@import AssetsLibrary;
#import "AwfulFrameworkCategories.h"
#import "AwfulTextAttachment.h"
#import "ComposeTextView.h"
#import <ImgurAnonymousAPIClient/ImgurAnonymousAPIClient.h>
#import <MRProgress/MRProgressOverlayView.h>
#import "UploadImageAttachments.h"
#import "Awful-Swift.h"

@interface ComposeTextViewController ()

@property (readonly, strong, nonatomic) UIView *viewToOverlay;
@property (strong, nonatomic) CompositionMenuTree *menuTree;

@end

@implementation ComposeTextViewController
{
    UIBarButtonItem *_submitButtonItem;
    UIBarButtonItem *_cancelButtonItem;
    id _keyboardWillShowObserver;
    id _keyboardWillHideObserver;
    id _textDidChangeObserver;
    NSProgress *_imageUploadProgress;
    NSLayoutConstraint *_customViewWidthConstraint;
}

- (void)dealloc
{
    [self endObservingKeyboardNotifications];
    [self endObservingTextChangeNotification];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        self.navigationItem.leftBarButtonItem = self.cancelButtonItem;
        self.navigationItem.rightBarButtonItem = self.submitButtonItem;
    }
    return self;
}

- (UIBarButtonItem *)submitButtonItem
{
    if (_submitButtonItem) return _submitButtonItem;
    _submitButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Submit"
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(didTapSubmit)];
    return _submitButtonItem;
}

- (UIBarButtonItem *)cancelButtonItem
{
    if (_cancelButtonItem) return _cancelButtonItem;
    _cancelButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                         style:UIBarButtonItemStylePlain
                                                        target:self
                                                        action:@selector(didTapCancel)];
    return _cancelButtonItem;
}

- (UITextView *)textView
{
    return (UITextView *)self.view;
}

- (void)loadView
{
    UITextView *textView = [ComposeTextView new];
    textView.restorationIdentifier = @"AwfulComposeTextView";
    textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
	textView.delegate = self;
    self.view = textView;
}

- (void)themeDidChange
{
    [super themeDidChange];
    self.textView.textColor = self.theme[@"listTextColor"];
    self.textView.keyboardAppearance = self.theme.keyboardAppearance;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.menuTree = [[CompositionMenuTree alloc] initWithTextView:self.textView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self focusInitialFirstResponder];
    [self updateSubmitButtonItem];
    [self beginObservingKeyboardNotifications];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self beginObservingTextChangeNotification];
}

- (void)updateSubmitButtonItem
{
    self.submitButtonItem.enabled = self.canSubmitComposition;
}

- (BOOL)canSubmitComposition
{
    return self.textView.text.length > 0;
}

- (void)beginObservingTextChangeNotification
{
    _textDidChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UITextViewTextDidChangeNotification
                                                                               object:self.textView
                                                                                queue:[NSOperationQueue mainQueue]
                                                                           usingBlock:^(NSNotification *note)
    {
        [self updateSubmitButtonItem];
    }];
}

- (void)endObservingTextChangeNotification
{
    if (_textDidChangeObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_textDidChangeObserver];
        _textDidChangeObserver = nil;
    }
}

- (void)shouldSubmitHandler:(void(^)(BOOL ok))handler
{
    handler(YES);
}

- (void)didTapSubmit
{
    [self disableEverythingButTheCancelButton];
    __weak __typeof__(self) weakSelf = self;
    [self shouldSubmitHandler:^(BOOL ok) {
        __typeof__(self) self = weakSelf;
        if (ok) {
            [self submit];
        } else {
            [_imageUploadProgress cancel];
            _imageUploadProgress = nil;
            [self enableEverything];
            [self focusInitialFirstResponder];
        }
    }];
}

- (void)submit
{
    MRProgressOverlayView *overlay = [MRProgressOverlayView showOverlayAddedTo:self.viewToOverlay
                                                                         title:self.submissionInProgressTitle
                                                                          mode:MRProgressOverlayViewModeIndeterminate
                                                                      animated:YES];
    overlay.tintColor = self.theme[@"tintColor"];

    __weak __typeof__(self) weakSelf = self;
    _imageUploadProgress = UploadImageAttachments(self.textView.attributedText, ^(NSString *plainText, NSError *error) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [overlay dismiss:NO];
            
            [self enableEverything];
            
            if (([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSUserCancelledError)) {
                [self focusInitialFirstResponder];
            } else {
                // In case we're covered up by subsequent view controllers (console message about "detached view controllers"), aim for our navigation controller.
                UIViewController *presenter = self.navigationController ?: self;
                [presenter presentViewController:[UIAlertController alertWithTitle:@"Image Upload Failed" error:error] animated:YES completion:nil];
            }
        } else {
            __weak __typeof__(self) weakSelf = self;
            [self submitComposition:plainText completionHandler:^(BOOL success) {
                __typeof__(self) self = weakSelf;
                [overlay dismiss:YES completion:^{
                    if (success) {
                        if (self.delegate) {
                            [self.delegate composeTextViewController:self didFinishWithSuccessfulSubmission:YES shouldKeepDraft:NO];
                        } else {
                            [self dismissViewControllerAnimated:YES completion:nil];
                        }
                    } else {
                        [self enableEverything];
                        [self focusInitialFirstResponder];
                    }
                }];
            }];
        }
    });
}

- (UIView *)viewToOverlay
{
    UINavigationController *navigationController = self.navigationController;
    if (navigationController) {
        return navigationController.topViewController.view;
    } else {
        return self.view;
    }
}

- (void)submitComposition:(NSString *)composition completionHandler:(void(^)(BOOL success))completionHandler
{
    [self doesNotRecognizeSelector:_cmd];
}

- (void)cancel
{
    if (self.delegate) {
        [self.delegate composeTextViewController:self didFinishWithSuccessfulSubmission:NO shouldKeepDraft:YES];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

- (void)setCustomView:(UIView<AwfulComposeCustomView> *)customView
{
    UIEdgeInsets textContainerInset = self.textView.textContainerInset;
    textContainerInset.top -= CGRectGetHeight(_customView.frame);
    [_customView removeFromSuperview];
    [_customView removeConstraint:_customViewWidthConstraint];
    _customViewWidthConstraint = nil;
    _customView = customView;
    if (!customView) {
        self.textView.textContainerInset = textContainerInset;
        return;
    }
    customView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.textView addSubview:customView];
    CGFloat height = CGRectGetHeight(customView.frame);
    textContainerInset.top += height;
    self.textView.textContainerInset = textContainerInset;
    NSDictionary *metrics = @{ @"height": @(height) };
    NSDictionary *views = NSDictionaryOfVariableBindings(customView);
    [self.textView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[customView]"
                                             options:0
                                             metrics:metrics
                                               views:views]];
    [self.textView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[customView(height)]"
                                             options:0
                                             metrics:metrics
                                               views:views]];
    _customViewWidthConstraint = [NSLayoutConstraint constraintWithItem:customView
                                                              attribute:NSLayoutAttributeWidth
                                                              relatedBy:NSLayoutRelationEqual
                                                                 toItem:nil
                                                              attribute:NSLayoutAttributeNotAnAttribute
                                                             multiplier:1
                                                               constant:CGRectGetWidth(self.view.bounds)];
    
    // If we're not in the view controller hierarchy, we might not yet have a width, in which case we'll add the constraint later.
    if (_customViewWidthConstraint.constant > 0) {
        [customView addConstraint:_customViewWidthConstraint];
    }
}

- (void)didTapCancel
{
    if (_imageUploadProgress) {
        [_imageUploadProgress cancel];
        _imageUploadProgress = nil;
        [MRProgressOverlayView dismissAllOverlaysForView:self.viewToOverlay animated:YES completion:^{
            [self enableEverything];
        }];
    } else {
        [self cancel];
    }
}

- (void)enableEverything
{
    [self updateSubmitButtonItem];
    self.textView.editable = YES;
    self.customView.enabled = YES;
}

- (void)focusInitialFirstResponder
{
    UIResponder *initialFirstResponder = self.customView.initialFirstResponder ?: self.textView;
    [initialFirstResponder becomeFirstResponder];
}

- (void)disableEverythingButTheCancelButton
{
    self.submitButtonItem.enabled = NO;
    [self.view endEditing:YES];
    self.textView.editable = NO;
    self.customView.enabled = NO;
}

- (void)beginObservingKeyboardNotifications
{
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    _keyboardWillShowObserver = [noteCenter addObserverForName:UIKeyboardWillShowNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note)
    {
        [self keyboardWillThingy:note];
    }];
    _keyboardWillHideObserver = [noteCenter addObserverForName:UIKeyboardWillHideNotification
                                                        object:nil
                                                         queue:[NSOperationQueue mainQueue]
                                                    usingBlock:^(NSNotification *note)
    {
        [self keyboardWillThingy:note];
    }];
}

- (void)endObservingKeyboardNotifications
{
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    if (_keyboardWillShowObserver) {
        [noteCenter removeObserver:_keyboardWillShowObserver];
        _keyboardWillShowObserver = nil;
    }
    if (_keyboardWillHideObserver) {
        [noteCenter removeObserver:_keyboardWillHideObserver];
        _keyboardWillHideObserver = nil;
    }
}

- (void)keyboardWillThingy:(NSNotification *)note
{
    NSTimeInterval duration = ((NSNumber *)note.userInfo[UIKeyboardAnimationDurationUserInfoKey]).doubleValue;
    UIViewAnimationCurve curve = ((NSNumber *)note.userInfo[UIKeyboardAnimationCurveUserInfoKey]).integerValue;
    UIViewAnimationOptions options = curve << 16;
    CGRect keyboardEndScreenFrame = ((NSValue *)note.userInfo[UIKeyboardFrameEndUserInfoKey]).CGRectValue;
    CGRect keyboardEndWindowFrame = [self.view.window convertRect:keyboardEndScreenFrame fromWindow:nil];
    CGRect keyboardEndTextViewFrame = [self.textView convertRect:keyboardEndWindowFrame fromView:nil];
    CGRect overlap = CGRectIntersection(keyboardEndTextViewFrame, self.textView.bounds);
    UIEdgeInsets contentInset = self.textView.contentInset;
    UIEdgeInsets indicatorInsets = self.textView.scrollIndicatorInsets;
    contentInset.bottom = CGRectGetHeight(overlap);
    indicatorInsets.bottom = CGRectGetHeight(overlap);
    [UIView animateWithDuration:duration delay:0 options:options animations:^{
        self.textView.contentInset = contentInset;
        self.textView.scrollIndicatorInsets = indicatorInsets;
    } completion:^(BOOL finished) {
        if ([note.name isEqualToString:UIKeyboardWillShowNotification]) {
            CGRect caretRect = [self.textView caretRectForPosition:self.textView.selectedTextRange.end];
            [self.textView scrollRectToVisible:caretRect animated:YES];
        }
    }];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    CGFloat width = CGRectGetWidth(self.view.bounds);
    if (_customViewWidthConstraint && width > 0) {
        _customViewWidthConstraint.constant = width;
        
        // If our view wasn't already in the hierarchy when the custom view was added, we didn't know how wide to make the custom view. Now we do.
        if (![self.customView.constraints containsObject:_customViewWidthConstraint]) {
            [self.customView addConstraint:_customViewWidthConstraint];
        }
        [self.view layoutSubviews];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self endObservingKeyboardNotifications];
    [self endObservingTextChangeNotification];
}

#pragma mark - UIViewControllerRestoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.textView.attributedText forKey:AttributedTextKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.textView.attributedText = [coder decodeObjectForKey:AttributedTextKey];
    
    // -viewDidLoad gets called before -decodeRestorableStateWithCoder: and so the text color gets loaded from the saved attributed string. Reapply the theme after restoring state.
    [self themeDidChange];
    
    [self updateSubmitButtonItem];
}

static NSString * const AttributedTextKey = @"AwfulAttributedText";

@end
