//  AwfulComposeTextView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulComposeTextView.h"
#import "AwfulKeyboardBar.h"
#import "AwfulTextAttachment.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <PSMenuItem/PSMenuItem.h>

@interface AwfulComposeTextView () <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPopoverControllerDelegate>

@property (strong, nonatomic) AwfulKeyboardBar *BBcodeBar;

@property (copy, nonatomic) NSArray *topLevelMenuItems;
@property (copy, nonatomic) NSArray *URLSubmenuItems;
@property (readonly, copy, nonatomic) NSArray *insertImageSubmenuItems;
@property (copy, nonatomic) NSArray *formattingSubmenuItems;

@end

@implementation AwfulComposeTextView
{
    BOOL _showingSubmenu;
    id _menuDidHideObserver;
    UIPopoverController *_imagePickerPopover;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame textContainer:(NSTextContainer *)textContainer
{
    self = [super initWithFrame:frame textContainer:textContainer];
    if (!self) return nil;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textDidChange_iOS7Fixes)
                                                 name:UITextViewTextDidChangeNotification
                                               object:nil];
    return self;
}

- (AwfulKeyboardBar *)BBcodeBar
{
    if (_BBcodeBar) return _BBcodeBar;
    _BBcodeBar = [AwfulKeyboardBar new];
    _BBcodeBar.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds),
                                  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 66 : 38);
    _BBcodeBar.strings = @[ @"[", @"=", @":", @"/", @"]", @"[/..]" ];
    _BBcodeBar.textView = self;
    _BBcodeBar.keyboardAppearance = self.keyboardAppearance;
    return _BBcodeBar;
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

#pragma mark - iOS 7 Fixes

// Found this stuff at https://github.com/Exile90/ICTextView/blob/master/ICTextView/ICTextView.m
// Not totally sure which parts fix which issues.

- (void)setSelectedTextRange:(UITextRange *)selectedTextRange
{
    [super setSelectedTextRange:selectedTextRange];
    if (selectedTextRange) {
        [self scrollRectToVisible:[self caretRectForPosition:selectedTextRange.end] animated:NO consideringInsets:YES];
    }
}

- (void)textDidChange_iOS7Fixes
{
    UITextRange *selectedTextRange = self.selectedTextRange;
    if (selectedTextRange) {
        [self scrollRectToVisible:[self caretRectForPosition:selectedTextRange.end] animated:NO consideringInsets:YES];
    }
}

- (void)scrollRectToVisible:(CGRect)rect animated:(BOOL)animated consideringInsets:(BOOL)considerInsets
{
    if (considerInsets) {
        CGRect bounds = self.bounds;
        UIEdgeInsets contentInset = self.contentInset;
        CGRect visibleRect = [self visibleRectConsideringInsets:YES];
        if (!CGRectContainsRect(visibleRect, rect)) {
            CGPoint contentOffset = self.contentOffset;
            if (rect.origin.y < visibleRect.origin.y) {
                contentOffset.y = rect.origin.y - contentInset.top;
            } else {
                contentOffset.y = rect.origin.y + contentInset.bottom + rect.size.height - bounds.size.height;
            }
            [self setContentOffset:contentOffset animated:animated];
        }
    } else {
        [super scrollRectToVisible:rect animated:animated];
    }
}

- (CGRect)visibleRectConsideringInsets:(BOOL)considerInsets
{
    if (considerInsets) {
        UIEdgeInsets contentInset = self.contentInset;
        CGRect visibleRect = self.bounds;
        visibleRect.origin.x += contentInset.left;
        visibleRect.origin.y += contentInset.top;
        visibleRect.size.width -= (contentInset.left + contentInset.right);
        visibleRect.size.height -= (contentInset.top + contentInset.bottom);
        return visibleRect;
    } else {
        return self.bounds;
    }
}

@end

const CGSize RequiresThumbnailImageSize = {800, 600};
