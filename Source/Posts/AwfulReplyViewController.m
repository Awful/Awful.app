//
//  AwfulReplyViewController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulReplyViewController.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "ImgurHTTPClient.h"
#import "NSString+CollapseWhitespace.h"
#import "PSMenuItem.h"
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"

@interface AwfulReplyViewController () <UIImagePickerControllerDelegate,
                                        UINavigationControllerDelegate, UIPopoverControllerDelegate>

@property (strong, nonatomic) UIBarButtonItem *sendButton;

@property (strong, nonatomic) UIBarButtonItem *cancelButton;

@property (readonly, nonatomic) UITextView *replyTextView;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (nonatomic) id observerToken;

@property (nonatomic) UIPopoverController *pickerPopover;

@property (nonatomic) NSMutableDictionary *images;

@property (nonatomic) AwfulThread *thread;

@property (nonatomic) AwfulPost *post;

@property (nonatomic) id <ImgurHTTPClientCancelToken> imageUploadCancelToken;

@end

@implementation AwfulReplyViewController

- (void)dealloc
{
    if (_observerToken) [[NSNotificationCenter defaultCenter] removeObserver:_observerToken];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (UITextView *)replyTextView
{
    return (UITextView *)self.view;
}

- (UIBarButtonItem *)sendButton
{
    if (_sendButton) return _sendButton;
    _sendButton = [[UIBarButtonItem alloc] initWithTitle:@"Reply"
                                                   style:UIBarButtonItemStyleDone
                                                  target:self
                                                  action:@selector(hitSend)];
    return _sendButton;
}

- (UIBarButtonItem *)cancelButton
{
    if (_cancelButton) return _cancelButton;
    _cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"Cancel"
                                                     style:UIBarButtonItemStyleBordered
                                                    target:self
                                                    action:@selector(cancel)];
    return _cancelButton;
}

- (void)editPost:(AwfulPost *)post text:(NSString *)text
{
    self.post = post;
    self.thread = nil;
    self.replyTextView.text = text;
    self.title = [post.thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Save";
    self.images = [NSMutableDictionary new];
}

- (void)replyToThread:(AwfulThread *)thread withInitialContents:(NSString *)contents
{
    self.thread = thread;
    self.post = nil;
    self.replyTextView.text = contents;
    self.title = [thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Reply";
    self.images = [NSMutableDictionary new];
}

- (void)keyboardDidShow:(NSNotification *)note
{
    CGRect keyboardFrame = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect relativeKeyboardFrame = [self.replyTextView convertRect:keyboardFrame fromView:nil];
    CGRect overlap = CGRectIntersection(relativeKeyboardFrame, self.replyTextView.bounds);
    // The 2 isn't strictly necessary, I just like a little cushion between the cursor and keyboard.
    UIEdgeInsets insets = (UIEdgeInsets){ .bottom = overlap.size.height + 2 };
    self.replyTextView.contentInset = insets;
    self.replyTextView.scrollIndicatorInsets = insets;
    [self.replyTextView scrollRangeToVisible:self.replyTextView.selectedRange];
}

- (void)keyboardWillHide:(NSNotification *)note
{
    self.replyTextView.contentInset = UIEdgeInsetsZero;
    self.replyTextView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (void)hitSend
{
    if (self.imageUploadCancelToken) return;
    [self.replyTextView resignFirstResponder];
    self.replyTextView.userInteractionEnabled = NO;
    if (AwfulSettings.settings.confirmBeforeReplying) {
        AwfulAlertView *alert = [AwfulAlertView new];
        alert.title = @"Incoming Forums Superstar";
        alert.message = @"Does my reply offer any significant advice or help "
                         "contribute to the conversation in any fashion?";
        [alert addCancelButtonWithTitle:@"Nope"
                                  block:^{ [self.replyTextView becomeFirstResponder]; }];
        [alert addButtonWithTitle:self.sendButton.title block:^{ [self send]; }];
        [alert show];
    } else {
        [self send];
    }
}

- (void)send
{
    [self.networkOperation cancel];
    
    NSString *reply = self.replyTextView.text;
    NSMutableArray *imageKeys = [NSMutableArray new];
    NSString *pattern = @"\\[(t?img)\\](imgur://(.+)\\.png)\\[/\\1\\]";
    NSError *error;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern
                                                                           options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"error parsing image URL placeholder regex: %@", error);
        return;
    }
    NSArray *placeholderResults = [regex matchesInString:reply
                                                 options:0
                                                   range:NSMakeRange(0, [reply length])];
    for (NSTextCheckingResult *result in placeholderResults) {
        NSRange rangeOfKey = [result rangeAtIndex:3];
        if (rangeOfKey.location == NSNotFound) continue;
        [imageKeys addObject:[reply substringWithRange:rangeOfKey]];
    }
    
    if ([imageKeys count] == 0) {
        [self completeReply:reply
withImagePlaceholderResults:placeholderResults
            replacementURLs:nil];
        return;
    }
    [SVProgressHUD showWithStatus:@"Uploading images…"];
    
    NSArray *images = [self.images objectsForKeys:imageKeys notFoundMarker:[NSNull null]];
    self.imageUploadCancelToken = [[ImgurHTTPClient client] uploadImages:images
                                                                 andThen:^(NSError *error,
                                                                           NSArray *urls)
     {
         self.imageUploadCancelToken = nil;
         if (!error) {
             [self completeReply:reply
     withImagePlaceholderResults:placeholderResults
                 replacementURLs:[NSDictionary dictionaryWithObjects:urls forKeys:imageKeys]];
             return;
         }
         [SVProgressHUD dismiss];
         [AwfulAlertView showWithTitle:@"Image Uploading Failed"
                                 error:error
                           buttonTitle:@"Fiddlesticks"];
     }];
}

- (void)completeReply:(NSString *)reply
    withImagePlaceholderResults:(NSArray *)placeholderResults
    replacementURLs:(NSDictionary *)replacementURLs
{
    [SVProgressHUD showWithStatus:self.thread ? @"Replying…" : @"Editing…"
                         maskType:SVProgressHUDMaskTypeClear];
    
    if ([placeholderResults count] > 0) {
        NSMutableString *replacedReply = [reply mutableCopy];
        NSInteger offset = 0;
        for (__strong NSTextCheckingResult *result in placeholderResults) {
            result = [result resultByAdjustingRangesWithOffset:offset];
            if ([result rangeAtIndex:3].location == NSNotFound) return;
            NSString *key = [reply substringWithRange:[result rangeAtIndex:3]];
            NSString *url = [replacementURLs[key] absoluteString];
            NSUInteger priorLength = [replacedReply length];
            if (url) {
                NSRange rangeOfURL = [result rangeAtIndex:2];
                rangeOfURL.location += offset;
                [replacedReply replaceCharactersInRange:rangeOfURL withString:url];
            } else {
                NSLog(@"found no associated image URL, so stripping tag %@",
                      [replacedReply substringWithRange:result.range]);
                [replacedReply replaceCharactersInRange:result.range withString:@""];
            }
            offset += ([replacedReply length] - priorLength);
        }
        reply = replacedReply;
    }
    
    if (self.thread) {
        [self sendReply:reply];
    } else if (self.post) {
        [self sendEdit:reply];
    }
    [self.replyTextView resignFirstResponder];
}

- (void)sendReply:(NSString *)reply
{
    id op = [[AwfulHTTPClient client] replyToThreadWithID:self.thread.threadID
                                                     text:reply
                                                  andThen:^(NSError *error, NSString *postID)
             {
                 if (error) {
                     [SVProgressHUD dismiss];
                     [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
                     return;
                 }
                 [SVProgressHUD showSuccessWithStatus:@"Replied"];
                 [self.delegate replyViewController:self didReplyToThread:self.thread];
             }];
    self.networkOperation = op;
}

- (void)sendEdit:(NSString *)edit
{
    id op = [[AwfulHTTPClient client] editPostWithID:self.post.postID
                                                text:edit
                                             andThen:^(NSError *error)
             {
                 if (error) {
                     [SVProgressHUD dismiss];
                     [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
                     return;
                 }
                 [SVProgressHUD showSuccessWithStatus:@"Edited"];
                 [self.delegate replyViewController:self didEditPost:self.post];
             }];
    self.networkOperation = op;
}

- (void)cancel
{
    [SVProgressHUD dismiss];
    if (self.imageUploadCancelToken) {
        [self.imageUploadCancelToken cancel];
        self.imageUploadCancelToken = nil;
        self.replyTextView.userInteractionEnabled = YES;
        [self.replyTextView becomeFirstResponder];
    } else {
        [self.delegate replyViewControllerDidCancel:self];
    }
}

- (void)retheme
{
    self.replyTextView.textColor = [AwfulTheme currentTheme].replyViewTextColor;
    self.replyTextView.backgroundColor = [AwfulTheme currentTheme].replyViewBackgroundColor;
    self.replyTextView.keyboardAppearance = UIKeyboardAppearanceAlert;
}

- (void)currentThemeChanged:(NSNotification *)note
{
    [self retheme];
}

#pragma mark - Menu items

- (void)configureTopLevelMenuItems
{
    [UIMenuController sharedMenuController].menuItems = @[
        [[PSMenuItem alloc] initWithTitle:@"[url]" block:^{ [self linkifySelection]; }],
        [[PSMenuItem alloc] initWithTitle:@"[img]" block:^{ [self insertImage]; }],
        [[PSMenuItem alloc] initWithTitle:@"Format" block:^{ [self showFormattingSubmenu]; }]
    ];
}

- (void)configureImageSourceSubmenuItems
{
    [UIMenuController sharedMenuController].menuItems = @[
        [[PSMenuItem alloc] initWithTitle:@"From Camera" block:^{ [self insertImageFromCamera]; }],
        [[PSMenuItem alloc] initWithTitle:@"From Library"
                                    block:^{ [self insertImageFromLibrary]; }],
    ];
}

- (void)configureFormattingSubmenuItems
{
    [UIMenuController sharedMenuController].menuItems = @[
        [[PSMenuItem alloc] initWithTitle:@"[b]" block:^{ [self wrapSelectionInTag:@"[b]"]; }],
        [[PSMenuItem alloc] initWithTitle:@"[s]" block:^{ [self wrapSelectionInTag:@"[s]"]; }],
        [[PSMenuItem alloc] initWithTitle:@"[u]" block:^{ [self wrapSelectionInTag:@"[u]"]; }],
        [[PSMenuItem alloc] initWithTitle:@"[i]" block:^{ [self wrapSelectionInTag:@"[i]"]; }],
        [[PSMenuItem alloc] initWithTitle:@"[spoiler]"
                                    block:^{ [self wrapSelectionInTag:@"[spoiler]"]; }],
        [[PSMenuItem alloc] initWithTitle:@"[fixed]"
                                    block:^{ [self wrapSelectionInTag:@"[fixed]"]; }],
        [[PSMenuItem alloc] initWithTitle:@"[quote]"
                                    block:^{ [self wrapSelectionInTag:@"[quote=]\n"]; }],
        [[PSMenuItem alloc] initWithTitle:@"[code]"
                                    block:^{ [self wrapSelectionInTag:@"[code]\n"]; }],
    ];
}

- (void)linkifySelection
{
    NSError *error;
    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink
                                                                   error:&error];
    if (!linkDetector) {
        NSLog(@"error creating link data detector: %@", linkDetector);
        return;
    }
    NSRange selectedRange = self.replyTextView.selectedRange;
    NSString *selection = [self.replyTextView.text substringWithRange:selectedRange];
    NSRange everything = NSMakeRange(0, [selection length]);
    NSArray *matches = [linkDetector matchesInString:selection
                                             options:0
                                               range:everything];
    if ([matches count] == 1 && NSEqualRanges([matches[0] range], everything)) {
        [self wrapSelectionInTag:@"[url]"];
    } else {
        [self wrapSelectionInTag:@"[url=]"];
    }
}

- (void)insertImage
{
    BOOL camera = [UIImagePickerController isSourceTypeAvailable:
                   UIImagePickerControllerSourceTypeCamera];
    BOOL library = [UIImagePickerController isSourceTypeAvailable:
                    UIImagePickerControllerSourceTypePhotoLibrary];
    if (!camera && !library) return;
    if (camera && !library) {
        [self insertImageFromCamera];
        return;
    } else if (library && !camera) {
        [self insertImageFromLibrary];
        return;
    }
    
    [self configureImageSourceSubmenuItems];
    [self showSubmenuThenResetToTopLevelMenuOnHide];
}

- (CGRect)selectedTextRect
{
    UITextRange *selection = self.replyTextView.selectedTextRange;
    CGRect startRect = [self.replyTextView caretRectForPosition:selection.start];
    CGRect endRect = [self.replyTextView caretRectForPosition:selection.end];
    return CGRectUnion(startRect, endRect);
}

- (void)showSubmenuThenResetToTopLevelMenuOnHide
{
    [[UIMenuController sharedMenuController] setTargetRect:[self selectedTextRect]
                                                    inView:self.view];
    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
    
    // Need to reset the menu items after a submenu item is chosen, but also if the menu disappears
    // for any other reason.
    __weak NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    self.observerToken = [center addObserverForName:UIMenuControllerDidHideMenuNotification
                                             object:nil
                                              queue:[NSOperationQueue mainQueue]
                                         usingBlock:^(NSNotification *note)
                          {
                              [center removeObserver:self.observerToken];
                              self.observerToken = nil;
                              [self configureTopLevelMenuItems];
                          }];
}

- (void)insertImageFromCamera
{
    UIImagePickerController *picker;
    picker = ImagePickerForSourceType(UIImagePickerControllerSourceTypeCamera);
    if (!picker) return;
    picker.delegate = self;
    [self presentModalViewController:picker animated:YES];
}

- (void)insertImageFromLibrary
{
    UIImagePickerController *picker;
    picker = ImagePickerForSourceType(UIImagePickerControllerSourceTypePhotoLibrary);
    if (!picker) return;
    picker.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.pickerPopover = [[UIPopoverController alloc] initWithContentViewController:picker];
        self.pickerPopover.delegate = self;
        [self.pickerPopover presentPopoverFromRect:[self selectedTextRect]
                                            inView:self.replyTextView
                          permittedArrowDirections:UIPopoverArrowDirectionAny
                                          animated:YES];
    } else {
        [self presentModalViewController:picker animated:YES];
    }
}

static UIImagePickerController *ImagePickerForSourceType(NSInteger sourceType)
{
    if (![UIImagePickerController isSourceTypeAvailable:sourceType]) return nil;
    NSArray *available = [UIImagePickerController availableMediaTypesForSourceType:sourceType];
    if (![available containsObject:(NSString *)kUTTypeImage]) return nil;
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = sourceType;
    picker.mediaTypes = @[ (NSString *)kUTTypeImage ];
    picker.allowsEditing = NO;
    return picker;
}

- (void)showFormattingSubmenu
{
    [self configureFormattingSubmenuItems];
    [self showSubmenuThenResetToTopLevelMenuOnHide];
}

- (void)wrapSelectionInTag:(NSString *)tag
{
    NSMutableString *closingTag = [tag mutableCopy];
    [closingTag insertString:@"/" atIndex:1];
    [closingTag replaceOccurrencesOfString:@"="
                                withString:@""
                                   options:0
                                     range:NSMakeRange(0, [closingTag length])];
    if ([tag hasSuffix:@"\n"]) {
        [closingTag insertString:@"\n" atIndex:0];
    }
    NSRange range = self.replyTextView.selectedRange;
    NSString *selection = [self.replyTextView.text substringWithRange:range];
    NSString *tagged = [NSString stringWithFormat:@"%@%@%@", tag, selection, closingTag];
    [self.replyTextView replaceRange:self.replyTextView.selectedTextRange withText:tagged];
    NSRange equalsSign = [tag rangeOfString:@"="];
    if (equalsSign.location == NSNotFound && ![tag hasSuffix:@"\n"]) {
        self.replyTextView.selectedRange = NSMakeRange(range.location + [tag length], range.length);
    } else {
        self.replyTextView.selectedRange = NSMakeRange(range.location + equalsSign.location + 1, 0);
    }
    [self.replyTextView becomeFirstResponder];
}

#pragma mark - UIViewController

- (void)loadView
{
    UITextView *textView = [UITextView new];
    textView.font = [UIFont systemFontOfSize:17];
    self.view = textView;
    [PSMenuItem installMenuHandlerForObject:self.view];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
    self.navigationItem.rightBarButtonItem = self.sendButton;
    self.navigationItem.leftBarButtonItem = self.cancelButton;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self configureTopLevelMenuItems];
    [self.replyTextView becomeFirstResponder];
    [self retheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(currentThemeChanged:)
                                                 name:AwfulThemeDidChangeNotification
                                               object:nil];
    self.replyTextView.userInteractionEnabled = YES;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AwfulThemeDidChangeNotification
                                                  object:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    if ([info[UIImagePickerControllerMediaType] isEqual:(NSString *)kUTTypeImage]) {
        UIImage *image = info[UIImagePickerControllerEditedImage];
        if (!image) image = info[UIImagePickerControllerOriginalImage];
        NSNumberFormatterStyle numberStyle = NSNumberFormatterSpellOutStyle;
        NSString *key = [NSNumberFormatter localizedStringFromNumber:@([self.images count] + 1)
                                                         numberStyle:numberStyle];
        // TODO when we implement reloading state after termination, save images to Caches folder.
        self.images[key] = image;
        
        // "Keep all images smaller than **800 pixels horizontal and 600 pixels vertical.**"
        // http://www.somethingawful.com/d/forum-rules/forum-rules.php?page=2
        BOOL shouldThumbnail = image.size.width > 800 || image.size.height > 600;
        [self.replyTextView replaceRange:self.replyTextView.selectedTextRange
                                withText:ImageKeyToPlaceholder(key, shouldThumbnail)];
    }
    if (self.pickerPopover) {
        [self.pickerPopover dismissPopoverAnimated:YES];
        self.pickerPopover = nil;
    } else {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
    [self.replyTextView becomeFirstResponder];
}

static NSString *ImageKeyToPlaceholder(NSString *key, BOOL thumbnail)
{
    NSString *t = thumbnail ? @"t" : @"";
    return [NSString stringWithFormat:@"[%@img]imgur://%@.png[/%@img]", t, key, t];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    // This seemingly never gets called when the picker is in a popover, so we can just blindly
    // dismiss it.
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.replyTextView becomeFirstResponder];
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
    [self.replyTextView becomeFirstResponder];
}

@end
