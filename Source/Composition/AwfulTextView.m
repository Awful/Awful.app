//
//  AwfulTextView.m
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import "AwfulTextView.h"
#import "NSURL+Punycode.h"
#import "PSMenuItem.h"

@interface AwfulTextView ()

@property (nonatomic) BOOL showStandardMenuItems;

@end


@implementation AwfulTextView

- (void)configureTopLevelMenuItems
{
    [UIMenuController sharedMenuController].menuItems = @[
        [[PSMenuItem alloc] initWithTitle:@"[url]"
                                    block:^{ [self showURLMenuOrLinkifySelection]; }],
        [[PSMenuItem alloc] initWithTitle:@"[img]" block:^{ [self insertImage]; }],
        [[PSMenuItem alloc] initWithTitle:@"Format" block:^{ [self showFormattingSubmenu]; }]
    ];
    self.showStandardMenuItems = YES;
}

- (void)showURLMenuOrLinkifySelection
{
    NSURL *copiedURL = [UIPasteboard generalPasteboard].URL;
    if (!copiedURL) {
        copiedURL = [NSURL awful_URLWithString:[UIPasteboard generalPasteboard].string];
    }
    if (copiedURL) {
        [self configureURLSubmenuItems];
        [self showSubmenuThenResetToTopLevelMenuOnHide];
    } else {
        [self linkifySelection];
    }
}

- (void)configureURLSubmenuItems
{
    PSMenuItem *tag = [[PSMenuItem alloc] initWithTitle:@"[url]"
                                                  block:^{ [self linkifySelection]; }];
    PSMenuItem *paste = [[PSMenuItem alloc] initWithTitle:@"Paste" block:^{ [self pasteURL]; }];
    [UIMenuController sharedMenuController].menuItems = @[ tag, paste ];
    self.showStandardMenuItems = NO;
}

- (void)linkifySelection
{
    NSError *error;
    NSDataDetector *linkDetector = [NSDataDetector dataDetectorWithTypes:(NSTextCheckingTypes)NSTextCheckingTypeLink
                                                                   error:&error];
    if (!linkDetector) {
        NSLog(@"error creating link data detector: %@", linkDetector);
        return;
    }
    NSRange selectedRange = self.selectedRange;
    NSString *selection = [self.text substringWithRange:selectedRange];
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

- (void)wrapSelectionInTag:(NSString *)tag
{
    NSRange equalsPart = [tag rangeOfString:@"="];
    NSRange end = [tag rangeOfString:@"]"];
    if (equalsPart.location != NSNotFound) {
        equalsPart.length = end.location - equalsPart.location;
    }
    NSMutableString *closingTag = [tag mutableCopy];
    if (equalsPart.location != NSNotFound) {
        [closingTag deleteCharactersInRange:equalsPart];
    }
    [closingTag insertString:@"/" atIndex:1];
    if ([tag hasSuffix:@"\n"]) {
        [closingTag insertString:@"\n" atIndex:0];
    }
    NSRange range = self.selectedRange;
    NSString *selection = [self.text substringWithRange:range];
    NSString *tagged = [NSString stringWithFormat:@"%@%@%@", tag, selection, closingTag];
    [self replaceRange:self.selectedTextRange withText:tagged];
    if (equalsPart.location == NSNotFound && ![tag hasSuffix:@"\n"]) {
        self.selectedRange = NSMakeRange(range.location + [tag length], range.length);
    } else if (equalsPart.length == 1 || range.length == 0) {
        self.selectedRange = NSMakeRange(range.location + equalsPart.location +
                                                       equalsPart.length + 1, 0);
    } else {
        self.selectedRange = NSMakeRange(range.location + range.length +
                                                       [tag length] + [closingTag length], 0);
    }
    [self becomeFirstResponder];
}

- (void)pasteURL
{
    NSURL *copiedURL = [UIPasteboard generalPasteboard].URL;
    if (!copiedURL) {
        copiedURL = [NSURL awful_URLWithString:[UIPasteboard generalPasteboard].string];
    }
    NSString *tag = [NSString stringWithFormat:@"[url=%@]", copiedURL.absoluteString];
    [self wrapSelectionInTag:tag];
}

- (void)showSubmenuThenResetToTopLevelMenuOnHide
{
    [[UIMenuController sharedMenuController] setMenuVisible:NO];
    [[UIMenuController sharedMenuController] setTargetRect:[self selectedTextRect] inView:self];
    [[UIMenuController sharedMenuController] setMenuVisible:YES animated:YES];
    
    // Need to reset the menu items after a submenu item is chosen, but also if the menu disappears
    // for any other reason.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(menuDidHide:)
                                                 name:UIMenuControllerDidHideMenuNotification
                                               object:nil];
}

- (CGRect)selectedTextRect
{
    UITextRange *selection = self.selectedTextRange;
    CGRect startRect = [self caretRectForPosition:selection.start];
    CGRect endRect = [self caretRectForPosition:selection.end];
    return CGRectUnion(startRect, endRect);
}

- (void)menuDidHide:(NSNotification *)note
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIMenuControllerDidHideMenuNotification
                                                  object:nil];
    [self configureTopLevelMenuItems];
}

- (void)insertImage
{
    if ([self.delegate respondsToSelector:@selector(textView:showImagePickerForSourceType:)]) {
        [self configureImageSourceSubmenuItems];
        [self showSubmenuThenResetToTopLevelMenuOnHide];
    } else {
        [self wrapSelectionInTag:@"[img]"];
    }
}

- (void)configureImageSourceSubmenuItems
{
    NSMutableArray *menuItems = [NSMutableArray new];
    UIImagePickerControllerSourceType camera = UIImagePickerControllerSourceTypeCamera;
    if ([UIImagePickerController isSourceTypeAvailable:camera]) {
        [menuItems addObject:[[PSMenuItem alloc] initWithTitle:@"From Camera" block:^{
            [self.delegate textView:self showImagePickerForSourceType:camera]; }]];
    }
    UIImagePickerControllerSourceType library = UIImagePickerControllerSourceTypePhotoLibrary;
    if ([UIImagePickerController isSourceTypeAvailable:library]) {
        [menuItems addObject:[[PSMenuItem alloc] initWithTitle:@"From Library" block:^{
            [self.delegate textView:self showImagePickerForSourceType:library]; }]];
    }
    [menuItems addObject:[[PSMenuItem alloc] initWithTitle:@"[img]" block:^{
        [self wrapSelectionInTag:@"[img]"]; }]];
    BOOL delegateCares = [self.delegate respondsToSelector:@selector(textView:insertImage:)];
    if ([UIPasteboard generalPasteboard].image && delegateCares) {
        [menuItems addObject:[[PSMenuItem alloc] initWithTitle:@"Paste" block:^{
            [self.delegate textView:self insertImage:[UIPasteboard generalPasteboard].image];
            [self becomeFirstResponder];
        }]];
    }
    [UIMenuController sharedMenuController].menuItems = menuItems;
    self.showStandardMenuItems = NO;
}

- (void)showFormattingSubmenu
{
    [self configureFormattingSubmenuItems];
    [self showSubmenuThenResetToTopLevelMenuOnHide];
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
    self.showStandardMenuItems = NO;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UITextView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    [self commonInit];
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (!(self = [super initWithCoder:aDecoder])) return nil;
    [self commonInit];
    return self;
}

- (void)commonInit
{
    [PSMenuItem installMenuHandlerForObject:self];
}

- (BOOL)becomeFirstResponder
{
    if (![super becomeFirstResponder]) return NO;
    [self configureTopLevelMenuItems];
    return YES;
}

- (BOOL)resignFirstResponder
{
    if (![super resignFirstResponder]) return NO;
    [UIMenuController sharedMenuController].menuItems = nil;
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    return self.showStandardMenuItems && [super canPerformAction:action withSender:sender];
}

@end
