//  AwfulComposeTextViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulComposeTextViewController.h"
#import "AwfulAlertView.h"
#import "AwfulComposeTextView.h"
#import "ImgurHTTPClient.h"
#import <SVProgressHUD/SVProgressHUD.h>

@implementation AwfulComposeTextViewController
{
    UIBarButtonItem *_submitButtonItem;
    UIBarButtonItem *_cancelButtonItem;
    id _textDidChangeObserver;
    id _keyboardWillShowObserver;
    id _keyboardWillHideObserver;
    id <ImgurHTTPClientCancelToken> _imageUploadCancelToken;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.navigationItem.leftBarButtonItem = self.cancelButtonItem;
    self.navigationItem.rightBarButtonItem = self.submitButtonItem;
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
    UITextView *textView = [AwfulComposeTextView new];
    textView.restorationIdentifier = @"AwfulComposeTextView";
    textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    self.view = textView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateSubmitButtonItem];
    [self beginObservingKeyboardNotifications];
    [self focusInitialFirstResponder];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    _textDidChangeObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UITextViewTextDidChangeNotification
                                                                               object:self.textView
                                                                                queue:[NSOperationQueue mainQueue]
                                                                           usingBlock:^(NSNotification *note)
    {
        [self updateSubmitButtonItem];
    }];
}

- (void)updateSubmitButtonItem
{
    self.submitButtonItem.enabled = self.canSubmitComposition;
}

- (BOOL)canSubmitComposition
{
    return self.textView.text.length > 0;
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
            [self enableEverything];
            [self focusInitialFirstResponder];
        }
    }];
}

- (void)submit
{
    __weak __typeof__(self) weakSelf = self;
    NSMutableAttributedString *submission = [self.textView.attributedText mutableCopy];
    void (^submit)(void) = ^{
        __typeof__(self) self = weakSelf;
        [SVProgressHUD showWithStatus:self.submissionInProgressTitle];
        [self submitComposition:submission.string completionHandler:^(BOOL success) {
            [SVProgressHUD dismiss];
            if (success) {
                [self.delegate composeTextViewController:self didFinishWithSuccessfulSubmission:YES];
            } else {
                [self enableEverything];
                [self focusInitialFirstResponder];
            }
        }];
    };
    
    NSMutableArray *attachments = [NSMutableArray new];
    [submission enumerateAttribute:NSAttachmentAttributeName
                           inRange:NSMakeRange(0, submission.length)
                           options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                        usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop)
    {
        if (attachment) {
            [attachments addObject:attachment];
        }
    }];
    if (attachments.count == 0) {
        submit();
        return;
    }
    
    [SVProgressHUD showWithStatus:@"Uploading images…"];
    
    _imageUploadCancelToken = [[ImgurHTTPClient client] uploadImages:[attachments valueForKey:@"image"]
                                                             andThen:^(NSError *error, NSArray *URLs)
    {
        __typeof__(self) self = weakSelf;
        _imageUploadCancelToken = nil;
        if (error) {
            [SVProgressHUD dismiss];
            [AwfulAlertView showWithTitle:@"Image Upload Failed" error:error buttonTitle:@"OK" completion:^{
                [self enableEverything];
            }];
        } else {
            [submission enumerateAttribute:NSAttachmentAttributeName
                                   inRange:NSMakeRange(0, submission.length)
                                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                                usingBlock:^(NSTextAttachment *attachment, NSRange range, BOOL *stop)
             {
                 if (!attachment) return;
                 NSURL *URL = URLs[[attachments indexOfObject:attachment]];
                 
                 NSString *t = @"";
                 CGSize imageSize = attachment.image.size;
                 if (imageSize.width > RequiresThumbnailImageSize.width ||
                     imageSize.height > RequiresThumbnailImageSize.height) {
                     t = @"t";
                 }
                 
                 NSString *replacement = [NSString stringWithFormat:@"[%@img]%@[/%@img]", t, URL.absoluteString, t];
                 [submission replaceCharactersInRange:range withString:replacement];
             }];
            submit();
        }
    }];
}

- (void)submitComposition:(NSString *)composition completionHandler:(void(^)(BOOL success))completionHandler
{
    [self doesNotRecognizeSelector:_cmd];
}

- (void)didTapCancel
{
    if (_imageUploadCancelToken) {
        [_imageUploadCancelToken cancel], _imageUploadCancelToken = nil;
        [SVProgressHUD dismiss];
        [self enableEverything];
    } else {
        [self.delegate composeTextViewController:self didFinishWithSuccessfulSubmission:NO];
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
    [noteCenter removeObserver:_keyboardWillShowObserver], _keyboardWillShowObserver = nil;
    [noteCenter removeObserver:_keyboardWillHideObserver], _keyboardWillHideObserver = nil;
}

- (void)keyboardWillThingy:(NSNotification *)note
{
    NSTimeInterval duration = ((NSNumber *)note.userInfo[UIKeyboardAnimationDurationUserInfoKey]).doubleValue;
    UIViewAnimationCurve curve = ((NSNumber *)note.userInfo[UIKeyboardAnimationCurveUserInfoKey]).integerValue;
    UIViewAnimationOptions options = curve << 16;
    CGRect keyboardEndScreenFrame = ((NSValue *)note.userInfo[UIKeyboardFrameEndUserInfoKey]).CGRectValue;
    CGRect keyboardEndWindowFrame = [self.view.window convertRect:keyboardEndScreenFrame fromWindow:nil];
    CGRect textViewWindowFrame = [self.textView.superview convertRect:self.textView.frame toView:nil];
    CGRect overlap = CGRectIntersection(keyboardEndWindowFrame, textViewWindowFrame);
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

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:_textDidChangeObserver], _textDidChangeObserver = nil;
    [self endObservingKeyboardNotifications];
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
}

static NSString * const AttributedTextKey = @"AwfulAttributedText";

@end
