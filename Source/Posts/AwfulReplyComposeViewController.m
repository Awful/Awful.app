//
//  AwfulReplyComposeViewController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulReplyComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient.h"
#import "AwfulKeyboardBar.h"
#import "AwfulModels.h"
#import "AwfulSettings.h"
#import "AwfulTextView.h"
#import "AwfulTheme.h"
#import "ImgurHTTPClient.h"
#import "NSString+CollapseWhitespace.h"
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"

@interface AwfulReplyComposeViewController () <UIImagePickerControllerDelegate,
                                               UINavigationControllerDelegate,
                                               UIPopoverControllerDelegate, AwfulTextViewDelegate,
                                               UITextViewDelegate>

@property (weak, nonatomic) NSOperation *networkOperation;

@property (nonatomic) UIPopoverController *pickerPopover;
@property (nonatomic) NSMutableDictionary *images;

@property (nonatomic) AwfulThread *thread;
@property (nonatomic) AwfulPost *post;

@property (nonatomic) id <ImgurHTTPClientCancelToken> imageUploadCancelToken;

@property (copy, nonatomic) NSString *savedReplyContents;
@property (nonatomic) NSRange savedSelectedRange;

@end


@implementation AwfulReplyComposeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.sendButton.target = self.cancelButton.target = self;
    self.sendButton.action = @selector(hitSend);
    self.cancelButton.action = @selector(cancel);
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)editPost:(AwfulPost *)post text:(NSString *)text
{
    self.post = post;
    self.thread = nil;
    self.textView.text = text;
    self.title = [post.thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Save";
    self.images = [NSMutableDictionary new];
    self.savedReplyContents = nil;
    self.savedSelectedRange = NSMakeRange(0, 0);
}

- (void)replyToThread:(AwfulThread *)thread withInitialContents:(NSString *)contents
{
    self.thread = thread;
    self.post = nil;
    self.textView.text = contents;
    self.title = [thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Reply";
    self.images = [NSMutableDictionary new];
    self.savedReplyContents = nil;
    self.savedSelectedRange = NSMakeRange(0, 0);
}

- (void)hitSend
{
    if (self.imageUploadCancelToken) return;
    [self.textView resignFirstResponder];
    self.textView.userInteractionEnabled = NO;
    if (AwfulSettings.settings.confirmBeforeReplying) {
        AwfulAlertView *alert = [AwfulAlertView new];
        alert.title = @"Incoming Forums Superstar";
        alert.message = @"Does my reply offer any significant advice or help "
                         "contribute to the conversation in any fashion?";
        [alert addCancelButtonWithTitle:@"Nope" block:^{
            self.textView.userInteractionEnabled = YES;
            [self.textView becomeFirstResponder];
        }];
        [alert addButtonWithTitle:self.sendButton.title block:^{ [self send]; }];
        [alert show];
    } else {
        [self send];
    }
}

- (void)send
{
    [self.networkOperation cancel];
    NSString *reply = self.textView.text;
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
         self.textView.userInteractionEnabled = YES;
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
            NSString *key = [replacedReply substringWithRange:[result rangeAtIndex:3]];
            NSString *url = [replacementURLs[key] absoluteString];
            NSUInteger priorLength = [replacedReply length];
            if (url) {
                NSRange rangeOfURL = [result rangeAtIndex:2];
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
    [self.textView resignFirstResponder];
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
                     self.textView.userInteractionEnabled = YES;
                     return;
                 }
                 [SVProgressHUD showSuccessWithStatus:@"Replied"];
                 [self.delegate replyComposeController:self didReplyToThread:self.thread];
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
                     self.textView.userInteractionEnabled = YES;
                     return;
                 }
                 [SVProgressHUD showSuccessWithStatus:@"Edited"];
                 [self.delegate replyComposeController:self didEditPost:self.post];
             }];
    self.networkOperation = op;
}

- (void)cancel
{
    [SVProgressHUD dismiss];
    if (self.imageUploadCancelToken) {
        [self.imageUploadCancelToken cancel];
        self.imageUploadCancelToken = nil;
        self.textView.userInteractionEnabled = YES;
        [self.textView becomeFirstResponder];
    } else {
        [self.delegate replyComposeControllerDidCancel:self];
    }
}

- (void)retheme
{
    self.textView.textColor = [AwfulTheme currentTheme].replyViewTextColor;
    self.textView.backgroundColor = [AwfulTheme currentTheme].replyViewBackgroundColor;
    self.textView.keyboardAppearance = UIKeyboardAppearanceAlert;
}

- (void)currentThemeChanged:(NSNotification *)note
{
    [self retheme];
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

#pragma mark - UIViewController

- (void)loadView
{
    self.view = self.textView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.textView becomeFirstResponder];
    [self retheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(currentThemeChanged:)
                                                 name:AwfulThemeDidChangeNotification
                                               object:nil];
    self.textView.userInteractionEnabled = YES;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AwfulThemeDidChangeNotification
                                                  object:nil];
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
    // dismiss it.
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
