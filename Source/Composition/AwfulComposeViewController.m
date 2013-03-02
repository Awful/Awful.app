//
//  AwfulComposeViewController.m
//  Awful
//
//  Created by Nolan Waite on 2013-02-26.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulKeyboardBar.h"
#import "AwfulTheme.h"
#import "ImgurHTTPClient.h"

@interface AwfulComposeViewController () <UIImagePickerControllerDelegate,
                                          UINavigationControllerDelegate,
                                          UIPopoverControllerDelegate>

@property (nonatomic) AwfulTextView *textView;

@property (nonatomic) NSMutableDictionary *images;
@property (weak, nonatomic) id <ImgurHTTPClientCancelToken> imageUploadCancelToken;
@property (nonatomic) UIPopoverController *pickerPopover;

@property (copy, nonatomic) NSString *savedReplyContents;
@property (nonatomic) NSRange savedSelectedRange;

@end


@implementation AwfulComposeViewController

- (AwfulTextView *)textView
{
    if (_textView) return _textView;
    _textView = [AwfulTextView new];
    _textView.delegate = self;
    _textView.frame = [UIScreen mainScreen].applicationFrame;
    _textView.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                  UIViewAutoresizingFlexibleHeight);
    _textView.font = [UIFont systemFontOfSize:17];
    _textView.keyboardAppearance = UIKeyboardAppearanceAlert;
    AwfulKeyboardBar *bbcodeBar = [AwfulKeyboardBar new];
    bbcodeBar.frame = CGRectMake(0, 0, CGRectGetWidth(_textView.bounds),
                                 UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 63 : 36);
    bbcodeBar.characters = @[ @"[", @"=", @":", @"/", @"]" ];
    bbcodeBar.keyInputView = _textView;
    _textView.inputAccessoryView = bbcodeBar;
    return _textView;
}

- (UIBarButtonItem *)sendButton
{
    if (_sendButton) return _sendButton;
    _sendButton = [[UIBarButtonItem alloc] initWithTitle:@"Send" style:UIBarButtonItemStyleDone
                                                  target:self action:@selector(cancel)];
    return _sendButton;
}

- (UIBarButtonItem *)cancelButton
{
    if (_cancelButton) return _cancelButton;
    _cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                     style:UIBarButtonItemStyleBordered
                                                    target:nil action:NULL];
    return _cancelButton;
}

- (void)retheme
{
    self.textView.textColor = [AwfulTheme currentTheme].replyViewTextColor;
    self.textView.backgroundColor = [AwfulTheme currentTheme].replyViewBackgroundColor;
}

- (void)prepareToSendMessage
{
    // TODO upload images, etc.
    NSArray *imagePlaceholderResults = ImagePlaceholderResultsWithMessageBody(self.textView.text);
    if ([imagePlaceholderResults count] > 0) {
        NSMutableArray *imageKeys = [NSMutableArray new];
        for (NSTextCheckingResult *result in imagePlaceholderResults) {
            NSRange range = [result rangeAtIndex:3];
            if (range.location == NSNotFound) continue;
            [imageKeys addObject:[self.textView.text substringWithRange:range]];
        }
        NSArray *images = [self.images objectsForKeys:imageKeys notFoundMarker:[NSNull null]];
        if ([images count] > 0) {
            [self willTransitionToState:AwfulComposeViewControllerStateUploadingImages];
            self.state = AwfulComposeViewControllerStateUploadingImages;
            id token = [[ImgurHTTPClient client] uploadImages:images
                                                      andThen:^(NSError *error, NSArray *urls)
            {
                if (error) {
                    [self willTransitionToState:AwfulComposeViewControllerStateError];
                    self.state = AwfulComposeViewControllerStateError;
                    [AwfulAlertView showWithTitle:@"Image Uploading Failed" error:error
                                      buttonTitle:@"OK" completion:^
                    {
                        [self willTransitionToState:AwfulComposeViewControllerStateReady];
                        self.state = AwfulComposeViewControllerStateReady;
                    }];
                    return;
                }
                NSDictionary *imgurURLs = [NSDictionary dictionaryWithObjects:urls
                                                                      forKeys:imageKeys];
                [self replaceImagePlaceholdersInMessageBody:self.textView.text
                                          atRangesInResults:imagePlaceholderResults
                                                   withURLs:imgurURLs];
            }];
            self.imageUploadCancelToken = token;
            return;
        }
    }
    [self replaceImagePlaceholdersInMessageBody:self.textView.text
                              atRangesInResults:imagePlaceholderResults
                                       withURLs:nil];
}

static NSArray * ImagePlaceholderResultsWithMessageBody(NSString *messageBody)
{
    NSString *pattern = @"\\[(t?img)\\](imgur://(.+)\\.png)\\[/\\1\\]";
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error parsing image URL placeholder regex: %@", error);
        return nil;
    }
    return [regex matchesInString:messageBody options:0 range:NSMakeRange(0, [messageBody length])];
}

- (void)replaceImagePlaceholdersInMessageBody:(NSString *)messageBody
                            atRangesInResults:(NSArray *)results
                                     withURLs:(NSDictionary *)urls
{
    [self willTransitionToState:AwfulComposeViewControllerStateSending];
    self.state = AwfulComposeViewControllerStateSending;
    NSMutableString *replacedBody = [messageBody mutableCopy];
    NSInteger offset = 0;
    for (__strong NSTextCheckingResult *result in results) {
        result = [result resultByAdjustingRangesWithOffset:offset];
        NSRange keyRange = [result rangeAtIndex:3];
        if (keyRange.location == NSNotFound) continue;
        NSString *key = [replacedBody substringWithRange:keyRange];
        NSString *url = [urls[key] absoluteString];
        NSUInteger priorLength = [replacedBody length];
        if (url) {
            [replacedBody replaceCharactersInRange:[result rangeAtIndex:2] withString:url];
        } else {
            NSLog(@"missing associated image URL for tag %@",
                  [replacedBody substringWithRange:result.range]);
            [replacedBody replaceCharactersInRange:result.range withString:@""];
        }
        offset += ([replacedBody length] - priorLength);
    }
    [self send:replacedBody];
}

- (void)send:(NSString *)messageBody
{
    [self doesNotRecognizeSelector:_cmd];
}

- (void)cancel
{
    [self.imageUploadCancelToken cancel];
    if (self.state != AwfulComposeViewControllerStateReady) {
        [self willTransitionToState:AwfulComposeViewControllerStateReady];
        self.state = AwfulComposeViewControllerStateReady;
    }
}

- (void)willTransitionToState:(AwfulComposeViewControllerState)state
{
    // noop; subclasses are free to implement
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    _images = [NSMutableDictionary new];
    self.navigationItem.rightBarButtonItem = self.sendButton;
    self.navigationItem.leftBarButtonItem = self.cancelButton;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeDidChange:)
                                                 name:AwfulThemeDidChangeNotification object:nil];
    self.modalPresentationStyle = UIModalPresentationPageSheet;
    return self;
}

- (void)themeDidChange:(NSNotification *)note
{
    if ([self isViewLoaded]) {
        [self retheme];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    [self retheme];
    [self willTransitionToState:AwfulComposeViewControllerStateReady];
    self.state = AwfulComposeViewControllerStateReady;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardDidShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (void)keyboardDidShow:(NSNotification *)note
{
    // TODO this is a bad way to do things, as the text view still puts stuff under the keyboard.
    // (for example, autocorrection suggestions)
    // Change the frame of the text view instead.
    CGRect keyboardFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect relativeKeyboardFrame = [self.textView convertRect:keyboardFrame fromView:nil];
    CGRect overlap = CGRectIntersection(relativeKeyboardFrame, self.textView.bounds);
    // The 2 isn't strictly necessary, I just like a little cushion between the cursor and keyboard.
    UIEdgeInsets inset = self.textView.contentInset;
    inset.bottom = overlap.size.height + 2;
    self.textView.contentInset = inset;
    self.textView.scrollIndicatorInsets = (UIEdgeInsets){ .bottom = inset.bottom };
    [self.textView scrollRangeToVisible:self.textView.selectedRange];
}

- (void)keyboardWillHide:(NSNotification *)note
{
    UIEdgeInsets inset = self.textView.contentInset;
    inset.bottom = 0;
    self.textView.contentInset = inset;
    self.textView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) return YES;
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - AwfulTextViewDelegate

- (void)textView:(AwfulTextView *)textView
showImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType
{
    if (![UIImagePickerController isSourceTypeAvailable:sourceType]) return;
    NSArray *available = [UIImagePickerController availableMediaTypesForSourceType:sourceType];
    if (![available containsObject:(NSString *)kUTTypeImage]) return;
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = sourceType;
    picker.mediaTypes = @[ (NSString *)kUTTypeImage ];
    picker.allowsEditing = NO;
    picker.delegate = self;
    BOOL iPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    if (iPad && sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
        self.pickerPopover = [[UIPopoverController alloc] initWithContentViewController:picker];
        self.pickerPopover.delegate = self;
        [self.pickerPopover presentPopoverFromRect:[self.textView selectedTextRect]
                                            inView:self.textView
                          permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    } else {
        [self saveTextView];
        [self presentModalViewController:picker animated:YES];
    }
}

// This save/load text view is only necessary on iOS 5, as UITextView throws everything out on a
// memory warning. It's fixed on iOS 6.
- (void)saveTextView
{
    self.savedReplyContents = self.textView.text;
    self.savedSelectedRange = self.textView.selectedRange;
}

- (void)loadTextView
{
    self.textView.text = self.savedReplyContents;
    self.textView.selectedRange = self.savedSelectedRange;
}

- (void)textView:(AwfulTextView *)textView insertImage:(UIImage *)image
{
    [self saveImageAndInsertPlaceholder:image];
}

- (void)saveImageAndInsertPlaceholder:(UIImage *)image
{
    NSNumberFormatterStyle numberStyle = NSNumberFormatterSpellOutStyle;
    NSString *key = [NSNumberFormatter localizedStringFromNumber:@([self.images count] + 1)
                                                     numberStyle:numberStyle];
    // TODO when we implement reloading state after termination, save images to Caches folder.
    self.images[key] = image;
    
    // "Keep all images smaller than **800 pixels horizontal and 600 pixels vertical.**"
    // http://www.somethingawful.com/d/forum-rules/forum-rules.php?page=2
    BOOL shouldThumbnail = image.size.width > 800 || image.size.height > 600;
    [self.textView replaceRange:self.textView.selectedTextRange
                       withText:ImageKeyToPlaceholder(key, shouldThumbnail)];
}

static NSString *ImageKeyToPlaceholder(NSString *key, BOOL thumbnail)
{
    NSString *t = thumbnail ? @"t" : @"";
    return [NSString stringWithFormat:@"[%@img]imgur://%@.png[/%@img]", t, key, t];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self loadTextView];
    }
    if ([info[UIImagePickerControllerMediaType] isEqual:(NSString *)kUTTypeImage]) {
        UIImage *image = info[UIImagePickerControllerEditedImage];
        if (!image) image = info[UIImagePickerControllerOriginalImage];
        [self saveImageAndInsertPlaceholder:image];
    }
    if (self.pickerPopover) {
        [self.pickerPopover dismissPopoverAnimated:YES];
        self.pickerPopover = nil;
    } else {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
    [self.textView becomeFirstResponder];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self loadTextView];
    // This seemingly never gets called when the picker is in a popover, so we can just blindly
    // dismiss the picker.
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.textView becomeFirstResponder];
}

#pragma mark - UINavigationControllerDelegate

// Set the title of the topmost view of the UIImagePickerController.
- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if ([navigationController.viewControllers count] == 1) {
        viewController.navigationItem.title = @"Insert Image";
    }
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (![popoverController isEqual:self.pickerPopover]) return;
    [self.textView becomeFirstResponder];
}

@end
