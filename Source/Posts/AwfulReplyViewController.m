//
//  AwfulReplyViewController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulReplyViewController.h"
#import "AwfulHTTPClient.h"
#import "AwfulPage.h"
#import "AwfulAppDelegate.h"
#import "ButtonSegmentedControl.h"
#import "ImgurHTTPClient.h"
#import "SVProgressHUD.h"

@interface AwfulReplyViewController () <UIAlertViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate>

@property (weak, nonatomic) IBOutlet UIBarButtonItem *sendButton;
@property (weak, nonatomic) IBOutlet UITextView *replyTextView;
@property (weak, nonatomic) IBOutlet ButtonSegmentedControl *segmentedControl;

@property (weak, nonatomic) NSOperation *networkOperation;

@property (getter=isShowingImageSourceSubmenu, nonatomic) BOOL showingImageSourceSubmenu;

@property (nonatomic) id observerToken;

@property (nonatomic) UIPopoverController *pickerPopover;

@property (nonatomic) NSMutableDictionary *images;

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

- (void)setPage:(AwfulPage *)page
{
    _page = page;
    self.images = [NSMutableDictionary new];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.segmentedControl.action = @selector(tappedSegment:);
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    self.replyTextView.text = self.startingText;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.sendButton.title = self.post ? @"Save" : @"Reply";
    [self configureImageMenuItem];
    [self.replyTextView becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - Responder overrides

- (BOOL)canBecomeFirstResponder
{
    return self.showingImageSourceSubmenu;
}

#pragma mark - Menu items

- (void)configureImageMenuItem
{
    [UIMenuController sharedMenuController].menuItems = @[
        [[UIMenuItem alloc] initWithTitle:@"[img]" action:@selector(insertImage:)]
    ];
    self.showingImageSourceSubmenu = NO;
}

- (void)configureImageSourceSubmenuItems
{
    [UIMenuController sharedMenuController].menuItems = @[
        [[UIMenuItem alloc] initWithTitle:@"From Camera" action:@selector(insertImageFromCamera:)],
        [[UIMenuItem alloc] initWithTitle:@"From Library" action:@selector(insertImageFromLibrary:)]
    ];
    self.showingImageSourceSubmenu = YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    if (action == @selector(insertImage:)) {
        if (self.showingImageSourceSubmenu) return NO;
        return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]
            || [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    }
    
    if (action == @selector(insertImageFromCamera:) || action == @selector(insertImageFromLibrary:)) {
        return self.showingImageSourceSubmenu;
    }
    
    if (self.showingImageSourceSubmenu) return NO;
    
    return [super canPerformAction:action withSender:sender];
}

- (void)insertImage:(id)sender
{
    BOOL camera = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    BOOL library = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
    if (!camera && !library) return;
    if (camera && !library) {
        [self insertImageFromCamera:nil];
        return;
    } else if (library && !camera) {
        [self insertImageFromLibrary:nil];
        return;
    }
    
    // At this point the menu has been dismissed, but we need it back where it was.
    [[UIMenuController sharedMenuController] setTargetRect:[self selectedTextRect]
                                                    inView:self.replyTextView];
    
    [self configureImageSourceSubmenuItems];
    
    // Jump out in front of the responder chain to hide the Paste menu item.
    [self becomeFirstResponder];
    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
    
    // Need to reset the menu items once an image source is chosen, but also if the menu disappears
    // for any other reason.
    __weak NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    self.observerToken = [center addObserverForName:UIMenuControllerDidHideMenuNotification
                                             object:nil
                                              queue:[NSOperationQueue mainQueue]
                                         usingBlock:^(NSNotification *note)
    {
        [center removeObserver:self.observerToken];
        self.observerToken = nil;
        [self configureImageMenuItem];
    }];
}

- (CGRect)selectedTextRect
{
    UITextRange *selection = self.replyTextView.selectedTextRange;
    CGRect startRect = [self.replyTextView caretRectForPosition:selection.start];
    CGRect endRect = [self.replyTextView caretRectForPosition:selection.end];
    return CGRectUnion(startRect, endRect);
}

- (void)insertImageFromCamera:(id)sender
{
    UIImagePickerController *picker = ImagePickerForSourceType(UIImagePickerControllerSourceTypeCamera);
    if (!picker) return;
    picker.delegate = self;
    [self presentModalViewController:picker animated:YES];
}

- (void)insertImageFromLibrary:(id)sender
{
    UIImagePickerController *picker = ImagePickerForSourceType(UIImagePickerControllerSourceTypePhotoLibrary);
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
    picker.allowsEditing = YES;
    return picker;
}

#pragma mark - Image picker delegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    if ([info[UIImagePickerControllerMediaType] isEqual:(NSString *)kUTTypeImage]) {
        UIImage *image = info[UIImagePickerControllerEditedImage];
        if (!image) image = info[UIImagePickerControllerOriginalImage];
        NSString *key = [NSNumberFormatter localizedStringFromNumber:@([self.images count] + 1)
                                                         numberStyle:NSNumberFormatterSpellOutStyle];
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
    return [NSString stringWithFormat:@"[%@img]awful://%@.png[/%@img]", t, key, t];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    // This seemingly never gets called when the picker is in a popover, so we can just blindly
    // dismiss it.
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.replyTextView becomeFirstResponder];
}

#pragma mark - Navigation controller delegate

// Set the title of the topmost view of the UIImagePickerController.
- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if ([navigationController.viewControllers count] == 1) {
        viewController.navigationItem.title = @"Insert Image";
    }
}

#pragma mark - Popover delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    if (![popoverController isEqual:self.pickerPopover]) return;
    [self.replyTextView becomeFirstResponder];
}

#pragma mark - Editing a reply

- (IBAction)tappedSegment:(id)sender
{
    NSInteger index = self.segmentedControl.selectedSegmentIndex;
    NSString *toInsert = [self.segmentedControl titleForSegmentAtIndex:index];
    [self.replyTextView replaceRange:self.replyTextView.selectedTextRange withText:toInsert];
    self.segmentedControl.selectedSegmentIndex = -1;
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

#pragma mark - Sending a reply (or not)

- (IBAction)hitSend
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Incoming Forums Superstar"
                                                    message:@"Does my reply offer any significant advice or help contribute to the conversation in any fashion?"
                                                   delegate:self
                                          cancelButtonTitle:@"Nope"
                                          otherButtonTitles:self.sendButton.title, nil];
    alert.delegate = self;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex != 1) return;
    
    [self.networkOperation cancel];
    
    NSString *reply = self.replyTextView.text;
    NSMutableArray *imageKeys = [NSMutableArray new];
    NSString *pattern = @"\\[(t?img)\\](awful://(.+)\\.png)\\[/\\1\\]";
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
    [SVProgressHUD showWithStatus:@"Uploading images…" maskType:SVProgressHUDMaskTypeClear];
    
    NSArray *images = [self.images objectsForKeys:imageKeys notFoundMarker:[NSNull null]];
    [[ImgurHTTPClient sharedClient] uploadImages:images andThen:^(NSError *error, NSArray *urls)
    {
        if (!error) {
            [self completeReply:reply
    withImagePlaceholderResults:placeholderResults
                replacementURLs:[NSDictionary dictionaryWithObjects:urls forKeys:imageKeys]];
            return;
        }
        [SVProgressHUD dismiss];
        NSString *message = [NSString stringWithFormat:@"Uploading images to imgur didn't work: %@",
                             [error localizedDescription]];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Image Uploading Failed"
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"Fiddlesticks"
                                              otherButtonTitles:nil];
        [alert show];
    }];
}

- (void)completeReply:(NSString *)reply
    withImagePlaceholderResults:(NSArray *)placeholderResults
    replacementURLs:(NSDictionary *)replacementURLs
{
    if (self.thread) [SVProgressHUD showWithStatus:@"Replying…" maskType:SVProgressHUDMaskTypeClear];
    else if (self.post) [SVProgressHUD showWithStatus:@"Editing…" maskType:SVProgressHUDMaskTypeClear];
    
    if ([placeholderResults count] > 0) {
        NSMutableString *replacedReply = [reply mutableCopy];
        NSInteger offset = 0;
        for (NSTextCheckingResult *result in placeholderResults) {
            NSRange rangeOfKey = [result rangeAtIndex:3];
            if (rangeOfKey.location == NSNotFound) return;
            rangeOfKey.location += offset;
            NSURL *url = replacementURLs[[reply substringWithRange:rangeOfKey]];
            if (!url) return;
            NSUInteger priorLength = [replacedReply length];
            NSRange rangeOfURL = [result rangeAtIndex:2];
            rangeOfURL.location += offset;
            [replacedReply replaceCharactersInRange:rangeOfURL withString:[url absoluteString]];
            offset += ([replacedReply length] - priorLength);
        }
        reply = replacedReply;
    }
    
    if (self.thread) {
        self.networkOperation = [[AwfulHTTPClient sharedClient] replyToThread:self.thread
                                                                     withText:reply
                                                                 onCompletion:^
                                 {
                                     [SVProgressHUD dismiss];
                                     [self.presentingViewController dismissModalViewControllerAnimated:YES];
                                     [self.page refresh];
                                 } onError:^(NSError *error)
                                 {
                                     [SVProgressHUD dismiss];
                                     [ApplicationDelegate requestFailed:error];
                                 }];
    } else if (self.post) {
        self.networkOperation = [[AwfulHTTPClient sharedClient] editPost:self.post
                                                            withContents:reply
                                                            onCompletion:^
                                 {
                                     [SVProgressHUD dismiss];
                                     [self.presentingViewController dismissModalViewControllerAnimated:YES];
                                     [self.page hardRefresh];
                                 } onError:^(NSError *error)
                                 {
                                     [SVProgressHUD dismiss];
                                     [ApplicationDelegate requestFailed:error];
                                 }];
    }
    [self.replyTextView resignFirstResponder];
}

- (IBAction)hideReply
{
    [SVProgressHUD dismiss];
    [self.presentingViewController dismissModalViewControllerAnimated:YES];
}

@end
