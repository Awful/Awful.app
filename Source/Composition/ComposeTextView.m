//  ComposeTextView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ComposeTextView.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulTextAttachment.h"
#import "KeyboardBar.h"
#import <PSMenuItem/PSMenuItem.h>
#import <Smilies/Smilies.h>

@interface ComposeTextView () <KeyboardBarDelegate, SmilieKeyboardDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate>

@property (strong, nonatomic) KeyboardBar *BBcodeBar;

@property (copy, nonatomic) NSArray *topLevelMenuItems;
@property (copy, nonatomic) NSArray *URLSubmenuItems;
@property (readonly, copy, nonatomic) NSArray *insertImageSubmenuItems;
@property (copy, nonatomic) NSArray *formattingSubmenuItems;

@property (strong, nonatomic) SmilieKeyboard *smilieKeyboard;
@property (assign, nonatomic) BOOL showingSmilieKeyboard;
@property (copy, nonatomic) NSString *justInsertedSmilieText;

@end

@implementation ComposeTextView
{
    BOOL _showingSubmenu;
    id _menuDidHideObserver;
    UIPopoverController *_imagePickerPopover;
}

- (KeyboardBar *)BBcodeBar
{
    if (_BBcodeBar) return _BBcodeBar;
    _BBcodeBar = [KeyboardBar new];
    _BBcodeBar.delegate = self;
    _BBcodeBar.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds),
                                  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 66 : 38);
    _BBcodeBar.textView = self;
    _BBcodeBar.keyboardAppearance = self.keyboardAppearance;
    return _BBcodeBar;
}

- (SmilieKeyboard *)smilieKeyboard
{
    if (!_smilieKeyboard) {
        _smilieKeyboard = [SmilieKeyboard new];
        _smilieKeyboard.delegate = self;
        _smilieKeyboard.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return _smilieKeyboard;
}

- (void)setShowingSmilieKeyboard:(BOOL)showingSmilieKeyboard
{
    _showingSmilieKeyboard = showingSmilieKeyboard;
    if (showingSmilieKeyboard && !self.inputView) {
        self.inputView = self.smilieKeyboard.view;
        [self reloadInputViews];
    } else if (!showingSmilieKeyboard && self.inputView) {
        self.inputView = nil;
        [self reloadInputViews];
    }
    if (!showingSmilieKeyboard) {
        self.justInsertedSmilieText = nil;
    }
}

#pragma mark - UIMenuController shenanigans

- (NSArray *)topLevelMenuItems
{
    if (_topLevelMenuItems) return _topLevelMenuItems;
    _topLevelMenuItems = @[ [[PSMenuItem alloc] initWithTitle:@"[url]" block:^{ [self showURLMenuOrLinkifySelection]; }],
                            [[PSMenuItem alloc] initWithTitle:@"[img]" block:^{ [self showInsertImageSubmenu]; }],
                            [[PSMenuItem alloc] initWithTitle:@"Format" block:^{ [self showFormattingSubmenu]; }] ];
    return _topLevelMenuItems;
}

- (NSArray *)URLSubmenuItems
{
    if (_URLSubmenuItems) return _URLSubmenuItems;
    _URLSubmenuItems = @[ [[PSMenuItem alloc] initWithTitle:@"[url]" block:^{ [self linkifySelection]; }],
                          [[PSMenuItem alloc] initWithTitle:@"Paste" block:^{ [self pasteURL]; }] ];
    return _URLSubmenuItems;
}

- (NSArray *)insertImageSubmenuItems
{
    NSMutableArray *items = [NSMutableArray new];
    if (IsImageAvailableForPickerSourceType(UIImagePickerControllerSourceTypeCamera)) {
        [items addObject:[[PSMenuItem alloc] initWithTitle:@"From Camera" block:^{ [self showImagePickerForCamera]; }]];
    }
    if (IsImageAvailableForPickerSourceType(UIImagePickerControllerSourceTypePhotoLibrary)) {
        [items addObject:[[PSMenuItem alloc] initWithTitle:@"From Library" block:^{ [self showImagePickerForLibrary]; }]];
    }
    [items addObject:[[PSMenuItem alloc] initWithTitle:@"[img]" block:^{ [self wrapSelectionInTag:@"[img]"]; }]];
    if ([UIPasteboard generalPasteboard].image) {
        [items addObject:[[PSMenuItem alloc] initWithTitle:@"Paste" block:^{
            [self insertImage:[UIPasteboard generalPasteboard].image withAssetURL:nil];
        }]];
    }
    return items;
}

- (NSArray *)formattingSubmenuItems
{
    if (_formattingSubmenuItems) return _formattingSubmenuItems;
    _formattingSubmenuItems = @[ [[PSMenuItem alloc] initWithTitle:@"[b]" block:^{ [self wrapSelectionInTag:@"[b]"]; }],
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
                                                             block:^{ [self wrapSelectionInTag:@"[code]\n"]; }] ];
    return _formattingSubmenuItems;
}

static BOOL IsImageAvailableForPickerSourceType(UIImagePickerControllerSourceType sourceType)
{
    return ([UIImagePickerController isSourceTypeAvailable:sourceType] &&
            [[UIImagePickerController availableMediaTypesForSourceType:sourceType] containsObject:(id)kUTTypeImage]);
}

- (void)useTopLevelMenu
{
    [UIMenuController sharedMenuController].menuItems = self.topLevelMenuItems;
    _showingSubmenu = NO;
}

- (void)immediatelyShowSubmenuWithItems:(NSArray *)items
{
    [UIMenuController sharedMenuController].menuItems = items;
    _showingSubmenu = YES;
    [UIMenuController sharedMenuController].menuVisible = NO;
    [[UIMenuController sharedMenuController] setTargetRect:self.selectionRect inView:self];
    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
    
    // Reset to top level menu items if the menu disappears for any reason.
    _menuDidHideObserver = [[NSNotificationCenter defaultCenter] addObserverForName:UIMenuControllerDidHideMenuNotification
                                                                             object:nil
                                                                              queue:[NSOperationQueue mainQueue]
                                                                         usingBlock:^(NSNotification *note)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:_menuDidHideObserver];
        [self useTopLevelMenu];
    }];
}

- (CGRect)selectionRect
{
    CGRect start = [self caretRectForPosition:self.selectedTextRange.start];
    return CGRectUnion(start, [self caretRectForPosition:self.selectedTextRange.end]);
}

- (void)showURLMenuOrLinkifySelection
{
    if ([UIPasteboard generalPasteboard].awful_URL) {
        [self immediatelyShowSubmenuWithItems:self.URLSubmenuItems];
    } else {
        [self linkifySelection];
    }
}

- (void)linkifySelection
{
    NSError *error;
    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:NSTextCheckingTypeLink error:&error];
    if (!linkDetector) {
        NSLog(@"%s error creating link data detector: %@", __PRETTY_FUNCTION__, error);
    }
    NSString *selection = [self.text substringWithRange:self.selectedRange];
    NSArray *matches = [linkDetector matchesInString:selection options:0 range:NSMakeRange(0, selection.length)];
    NSTextCheckingResult *firstMatch = matches.firstObject;
    if (firstMatch.range.length == selection.length && selection.length > 0) {
        [self wrapSelectionInTag:@"[url]"];
    } else {
        [self wrapSelectionInTag:@"[url=]"];
    }
}

- (void)pasteURL
{
    NSURL *URL = [UIPasteboard generalPasteboard].awful_URL;
    [self wrapSelectionInTag:[NSString stringWithFormat:@"[url=%@]", URL.absoluteString]];
}

- (void)showInsertImageSubmenu
{
    [self immediatelyShowSubmenuWithItems:self.insertImageSubmenuItems];
}

- (void)showImagePickerForCamera
{
    [self showImagePickerForSourceType:UIImagePickerControllerSourceTypeCamera];
}

- (void)showImagePickerForLibrary
{
    [self showImagePickerForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
}

- (void)showImagePickerForSourceType:(UIImagePickerControllerSourceType)sourceType
{
    UIImagePickerController *imagePickerController = [UIImagePickerController new];
    imagePickerController.sourceType = sourceType;
    imagePickerController.mediaTypes = @[ (id)kUTTypeImage ];
    imagePickerController.allowsEditing = NO;
    imagePickerController.delegate = self;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
        _imagePickerPopover = [[UIPopoverController alloc] initWithContentViewController:imagePickerController];
        _imagePickerPopover.delegate = self;
        [_imagePickerPopover presentPopoverFromRect:self.selectionRect
                                             inView:self
                           permittedArrowDirections:UIPopoverArrowDirectionAny
                                           animated:YES];
    } else {
        [[self nearestViewController] presentViewController:imagePickerController animated:YES completion:nil];
    }
}

- (UIViewController *)nearestViewController
{
    UIResponder *responder = self;
    while ((responder = [responder nextResponder])) {
        if ([responder isKindOfClass:[UIViewController class]]) {
            return (UIViewController *)responder;
        }
    }
    return nil;
}

- (void)wrapSelectionInTag:(NSString *)tagSpecifier
{
    NSRange equalsPart = [tagSpecifier rangeOfString:@"="];
    NSRange end = [tagSpecifier rangeOfString:@"]"];
    if (equalsPart.location != NSNotFound) {
        equalsPart.length = end.location - equalsPart.location;
    }
    NSMutableString *closingTag = [tagSpecifier mutableCopy];
    if (equalsPart.location != NSNotFound) {
        [closingTag deleteCharactersInRange:equalsPart];
    }
    [closingTag insertString:@"/" atIndex:1];
    if ([tagSpecifier hasSuffix:@"\n"]) {
        [closingTag insertString:@"\n" atIndex:0];
    }
    
    // Save this for post-replacement use.
    NSRange selectedRange = self.selectedRange;
    
    UITextRange *selection = self.selectedTextRange;
    
    // Order is important here if the selection has length zero. Otherwise it doesn't matter.
    UITextRange *after = [self textRangeFromPosition:selection.end toPosition:selection.end];
    [self replaceRange:after withText:closingTag];
    UITextRange *before = [self textRangeFromPosition:selection.start toPosition:selection.start];
    [self replaceRange:before withText:tagSpecifier];
    
    if (equalsPart.location == NSNotFound && ![tagSpecifier hasSuffix:@"\n"]) {
        selectedRange.location += tagSpecifier.length;
    } else if (equalsPart.length == 1) {
        selectedRange.location += equalsPart.location + equalsPart.length;
        selectedRange.length = 0;
    } else if (selectedRange.length == 0) {
        selectedRange.location += NSMaxRange(equalsPart) + 1;
    } else {
        selectedRange.location += selectedRange.length + tagSpecifier.length + closingTag.length;
        selectedRange.length = 0;
    }
    self.selectedRange = selectedRange;
    [self becomeFirstResponder];
}

- (void)insertImage:(UIImage *)image withAssetURL:(NSURL *)assetURL
{
    // For whatever reason we get the default font/text color after inserting an image, so keep our current font for later.
    UIFont *font = self.font;
	UIColor *textColor = self.textColor;
    
    AwfulTextAttachment *attachment = [AwfulTextAttachment new];
    attachment.image = image;
    attachment.assetURL = assetURL;
    NSAttributedString *string = [NSAttributedString attributedStringWithAttachment:attachment];
    [self.textStorage replaceCharactersInRange:self.selectedRange withAttributedString:string];
    UITextPosition *afterImage = [self positionFromPosition:self.selectedTextRange.end offset:1];
    self.selectedTextRange = [self textRangeFromPosition:afterImage toPosition:afterImage];
    
    self.font = font;
	self.textColor = textColor;
    
    // Notification doesn't get sent because we're manipulating the text storage directly. (I forget why, exactly, I chose the text storage over the text view's attributedString property. Naturally I didn't leave any useful commentary. I'm sorry.)
    [[NSNotificationCenter defaultCenter] postNotificationName:UITextViewTextDidChangeNotification object:self];
}

- (void)showFormattingSubmenu
{
    [self immediatelyShowSubmenuWithItems:self.formattingSubmenuItems];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    UIImage *image = info[UIImagePickerControllerEditedImage] ?: info[UIImagePickerControllerOriginalImage];
    [self insertImage:image withAssetURL:info[UIImagePickerControllerReferenceURL]];
    [self dismissImagePicker:picker];
    [self becomeFirstResponder];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissImagePicker:picker];
    [self becomeFirstResponder];
}

- (void)dismissImagePicker:(UIImagePickerController *)picker
{
    if (_imagePickerPopover) {
        [_imagePickerPopover dismissPopoverAnimated:NO];
        _imagePickerPopover = nil;
    } else {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - UIPopoverControllerDelegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    _imagePickerPopover = nil;
    [self becomeFirstResponder];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if ([viewController isEqual:navigationController.viewControllers.firstObject]) {
        viewController.navigationItem.title = @"Insert Image";
    }
}

#pragma mark - KeyboardBarDelegate

- (void)toggleSmilieKeyboardForKeyboardBar:(KeyboardBar *)keyboardBar
{
    self.showingSmilieKeyboard = !self.showingSmilieKeyboard;
}

#pragma mark - SmilieKeyboardDelegate

- (void)advanceToNextInputModeForSmilieKeyboard:(SmilieKeyboard *)keyboard
{
    self.showingSmilieKeyboard = NO;
}

- (void)deleteBackwardForSmilieKeyboard:(SmilieKeyboard *)keyboard
{
    if (self.selectedRange.length == 0 && self.justInsertedSmilieText) {
        NSRange locationOfSmilie = [self.text rangeOfString:self.justInsertedSmilieText options:(NSBackwardsSearch | NSAnchoredSearch) range:NSMakeRange(0, self.selectedRange.location)];
        if (locationOfSmilie.location != NSNotFound) {
            do {
                [self deleteBackward];
            } while (![self.text hasSuffix:@":"]);
        }
    }
    self.justInsertedSmilieText = nil;
    [self deleteBackward];
}

- (void)smilieKeyboard:(SmilieKeyboard *)keyboard didTapSmilie:(Smilie *)smilie
{
    [self insertText:smilie.text];
    self.justInsertedSmilieText = smilie.text;
    [smilie.managedObjectContext performBlock:^{
        smilie.metadata.lastUsedDate = [NSDate date];
        NSError *error;
        if (![smilie.managedObjectContext save:&error]) {
            NSLog(@"%s error saving after updating last used date: %@", __PRETTY_FUNCTION__, error);
        }
    }];
}

#pragma mark - UITextInputTraits

- (void)setKeyboardAppearance:(UIKeyboardAppearance)keyboardAppearance
{
    [super setKeyboardAppearance:keyboardAppearance];
    _BBcodeBar.keyboardAppearance = keyboardAppearance;
}

#pragma mark - UIResponder

- (BOOL)becomeFirstResponder
{
    self.inputAccessoryView = self.BBcodeBar;
    if (![super becomeFirstResponder]) {
        self.inputAccessoryView = nil;
        return NO;
    }
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [PSMenuItem installMenuHandlerForObject:self];
    });
    [self useTopLevelMenu];
    return YES;
}

- (BOOL)resignFirstResponder
{
    if (![super resignFirstResponder]) return NO;
    [UIMenuController sharedMenuController].menuItems = nil;
    self.inputAccessoryView = nil;
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    return !_showingSubmenu && [super canPerformAction:action withSender:sender];
}

@end

const CGSize RequiresThumbnailImageSize = {800, 600};
