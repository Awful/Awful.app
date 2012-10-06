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
#import "MBProgressHUD.h"
#import "ButtonSegmentedControl.h"

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
    [self.replyTextView becomeFirstResponder];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.sendButton.title = self.post ? @"Save" : @"Reply";
    
    [self configureImageMenuItem];
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
        NSString *placeholder = [NSString stringWithFormat:@"[img]chosen-image-%@[/img]", key];
        [self.replyTextView replaceRange:self.replyTextView.selectedTextRange
                                withText:placeholder];
    }
    // See below re: popover.
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.replyTextView becomeFirstResponder];
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

- (void)keyboardWillShow:(NSNotification *)note
{
    double duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    CGRect keyboardRect = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGRect keyboardBounds = [self.view convertRect:keyboardRect fromView:nil];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // using form sheet the keyboard doesn't overlap
        CGFloat height = self.view.bounds.size.height;
        CGFloat replyBoxHeight = height - 44 - (height - keyboardBounds.origin.y);
        replyBoxHeight = MAX(350, replyBoxHeight); // someone bugged out the height one time so I'm hacking in a minimum
        self.replyTextView.frame = CGRectMake(5, 44, self.replyTextView.bounds.size.width, replyBoxHeight);
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [UIView animateWithDuration:duration animations:^{
            self.replyTextView.frame = (CGRect){
                .origin = { 5, 44 },
                .size.width = self.replyTextView.bounds.size.width,
                .size.height = self.view.bounds.size.height - 44 - keyboardBounds.size.height
            };
        }];
    }
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
    
    if (self.thread) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
        hud.labelText = @"Replying…";
        self.networkOperation = [[AwfulHTTPClient sharedClient] replyToThread:self.thread
                                                                     withText:self.replyTextView.text
                                                                 onCompletion:^
                                 {
                                     [MBProgressHUD hideHUDForView:self.view animated:NO];
                                     [self.presentingViewController dismissModalViewControllerAnimated:YES];
                                     [self.page refresh];
                                 } onError:^(NSError *error)
                                 {
                                     [MBProgressHUD hideHUDForView:self.view animated:NO];
                                     [ApplicationDelegate requestFailed:error];
                                 }];
    } else if (self.post) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
        hud.labelText = @"Editing…";
        self.networkOperation = [[AwfulHTTPClient sharedClient] editPost:self.post
                                                            withContents:self.replyTextView.text
                                                            onCompletion:^
                                 {
                                     [MBProgressHUD hideHUDForView:self.view animated:NO];
                                     [self.presentingViewController dismissModalViewControllerAnimated:YES];
                                     [self.page hardRefresh];
                                 } onError:^(NSError *error)
                                 {
                                     [MBProgressHUD hideHUDForView:self.view animated:NO];
                                     [ApplicationDelegate requestFailed:error];
                                 }];
    }
    [self.replyTextView resignFirstResponder];
}

- (IBAction)hideReply
{
    [MBProgressHUD hideHUDForView:self.view animated:NO];
    [self.presentingViewController dismissModalViewControllerAnimated:YES];
}

@end
