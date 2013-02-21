//
//  AwfulEditorViewController.m
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposerViewController.h"
#import "AwfulComposerView.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient.h"
//#import "AwfulKeyboardBar.h"
#import "AwfulModels.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "PSMenuItem.h"
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"
#import "AwfulEmoticonChooserViewController.h"

@interface AwfulComposerViewController () <UIImagePickerControllerDelegate,
UINavigationControllerDelegate, UIPopoverControllerDelegate>

@property (readonly, nonatomic) UIBarButtonItem *insertOpenBracketButton;

@property (readonly, nonatomic) UIBarButtonItem *insertCloseBracketButton;

@property (readonly, nonatomic) UIBarButtonItem *insertEqualsButton;

@property (readonly, nonatomic) UIBarButtonItem *insertSlashButton;

@property (readonly, nonatomic) UIBarButtonItem *insertColonButton;

@property (readonly, nonatomic) UIBarButtonItem *insertAnotherColonButton;

@property (nonatomic) NSMutableAttributedString *attributedString;

@end

@implementation AwfulComposerViewController
{
    UIBarButtonItem *_insertOpenBracketButton;
    UIBarButtonItem *_insertCloseBracketButton;
    UIBarButtonItem *_insertEqualsButton;
    UIBarButtonItem *_insertSlashButton;
    UIBarButtonItem *_insertColonButton;
}

- (void)dealloc
{
    if (_observerToken) [[NSNotificationCenter defaultCenter] removeObserver:_observerToken];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillShowNotification
                                                  object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification
                                                  object:nil];
}

- (BOOL)canPullForNextPage {
    return NO;
}

- (BOOL)canPullToRefresh {
    return NO;
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
                                                    action:@selector(hitCancel)];
    return _cancelButton;
}

- (void)keyboardWillShow:(NSNotification *)note
{
    //UIEdgeInsets inset = self.tableView.contentInset;
    //self.tableView.contentInset = UIEdgeInsetsZero;
}

- (void)keyboardDidShow:(NSNotification *)note
{
    //UIEdgeInsets inset = self.tableView.contentInset;
    //self.tableView.contentInset = UIEdgeInsetsZero;
}

- (void)keyboardWillHide:(NSNotification *)note
{
    /*
    self.composerTextView.contentInset = UIEdgeInsetsZero;
    self.composerTextView.scrollIndicatorInsets = UIEdgeInsetsZero;
     */
}

- (void)cancel
{
    [SVProgressHUD dismiss];
    if (self.imageUploadCancelToken) {
        [self.imageUploadCancelToken cancel];
        self.imageUploadCancelToken = nil;
        self.composerTextView.userInteractionEnabled = YES;
        [self.composerTextView becomeFirstResponder];
    } else {
        [self.delegate composerViewControllerDidCancel:self];
    }
}

- (void)retheme
{
    self.composerTextView.textColor = [AwfulTheme currentTheme].replyViewTextColor;
    self.composerTextView.backgroundColor = [AwfulTheme currentTheme].replyViewBackgroundColor;
    self.composerTextView.keyboardAppearance = UIKeyboardAppearanceAlert;
}

- (void)currentThemeChanged:(NSNotification *)note
{
    [self retheme];
}

-(AwfulAlertView*) confirmationAlert
{
    AwfulAlertView *alert = [AwfulAlertView new];
    alert.title = @"Really send";
    alert.message = @"Really send?";
    [alert addCancelButtonWithTitle:@"Nope"
                              block:^{ [self.composerTextView becomeFirstResponder]; }];
    [alert addButtonWithTitle:self.sendButton.title block:^{ }];
    return alert;
}

- (void)hitSend
{
    if (self.imageUploadCancelToken) return;
    [self.composerTextView resignFirstResponder];
    self.composerTextView.userInteractionEnabled = NO;
    if (AwfulSettings.settings.confirmBeforeReplying) {
        //[self.confirmationAlert show];
    } else {
        //fixme: disabling this just to be safe during dev
    }
    [self prepareToSend];
}

- (void)prepareToSend
{
    [self.networkOperation cancel];
    
    NSString *reply = self.composerTextView.bbcode;
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
        [self replaceImagePlaceholdersForString:reply
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
                                           [self replaceImagePlaceholdersForString:reply
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

- (void)replaceImagePlaceholdersForString:(NSString *)reply
              withImagePlaceholderResults:(NSArray *)placeholderResults
                          replacementURLs:(NSDictionary *)replacementURLs
{
    //[SVProgressHUD showWithStatus:self.thread ? @"Replying…" : @"Editing…"
    //                     maskType:SVProgressHUDMaskTypeClear];
    
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
    
    [self.composerTextView resignFirstResponder];
    
    [self didReplaceImagePlaceholders:reply];
}

- (void)didReplaceImagePlaceholders:(NSString *)newMessageString {
    //subclasses need handle the new message string
    [self send];
}


-(void) send {
    [NSException raise:@"Subclass must override" format:nil];
}

- (AwfulEmoticonKeyboardController*)emoticonChooser {
    if (_emoticonChooser) return _emoticonChooser;
    _emoticonChooser = [AwfulEmoticonKeyboardController new];
    return _emoticonChooser;
}

#pragma mark TableView
//Subclasses may need to add more cells, ie Thread title, thread icon, etc

- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (int)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString* identifier = @"ComposerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [AwfulComposerTableViewCell new];
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    AwfulComposerTableViewCell *composerCell = (AwfulComposerTableViewCell*)cell;
    composerCell.composerView = self.composerTextView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *output = [self.composerTextView.innerWebView stringByEvaluatingJavaScriptFromString:@"document.getElementById('content').offsetHeight;"];
    return MAX(output.floatValue + 10, 200);
}

#pragma mark textview
- (void)textViewDidChange:(UITextView *)textView {
    //call these to force table to recalculate height
    //for dynamically growing input cell
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
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

- (void)showURLMenuOrLinkifySelection
{
    NSURL *copiedURL = [UIPasteboard generalPasteboard].URL;
    if (!copiedURL) {
        copiedURL = [NSURL URLWithString:[UIPasteboard generalPasteboard].string];
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
    //self.replyTextView.showStandardMenuItems = NO;
}

- (void)configureImageSourceSubmenuItems
{
    NSMutableArray *menuItems = [NSMutableArray new];
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [menuItems addObject:[[PSMenuItem alloc] initWithTitle:@"From Camera"
                                                         block:^{ [self insertImageFromCamera]; }]];
    }
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
        [menuItems addObject:[[PSMenuItem alloc] initWithTitle:@"From Library"
                                                         block:^{ [self insertImageFromLibrary]; }]];
    }
    [menuItems addObject:[[PSMenuItem alloc] initWithTitle:@"[img]"
                                                     block:^{ [self wrapSelectionInTag:@"[img]"]; }]];
    if ([UIPasteboard generalPasteboard].image) {
        [menuItems addObject:[[PSMenuItem alloc] initWithTitle:@"Paste" block:^{
            UIImage *image = [UIPasteboard generalPasteboard].image;
            [self saveImageAndInsertPlaceholder:image];
            //[self.replyTextView becomeFirstResponder];
        }]];
    }
    [UIMenuController sharedMenuController].menuItems = menuItems;
}

- (void)configureFormattingSubmenuItems
{
    [UIMenuController sharedMenuController].menuItems = @[
                                                          [[PSMenuItem alloc] initWithTitle:@"[b]" block:^{ [self formatSelectionWithTag:@"b"]; }],
                                                          [[PSMenuItem alloc] initWithTitle:@"[s]" block:^{ [self formatSelectionWithTag:@"s"]; }],
                                                          [[PSMenuItem alloc] initWithTitle:@"[u]" block:^{ [self formatSelectionWithTag:@"u"]; }],
                                                          [[PSMenuItem alloc] initWithTitle:@"[i]" block:^{ [self formatSelectionWithTag:@"i"]; }],
                                                          [[PSMenuItem alloc] initWithTitle:@"[spoiler]"
                                                                                      block:^{ [self formatSelectionWithTag:@"spoiler"]; }],
                                                          [[PSMenuItem alloc] initWithTitle:@"[fixed]"
                                                                                      block:^{ [self formatSelectionWithTag:@"[fixed]"]; }],
                                                          [[PSMenuItem alloc] initWithTitle:@"[quote]"
                                                                                      block:^{ [self wrapSelectionInTag:@"[quote=]\n"]; }],
                                                          [[PSMenuItem alloc] initWithTitle:@"[code]"
                                                                                      block:^{ [self wrapSelectionInTag:@"[code]\n"]; }],
                                                          ];
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
    NSRange selectedRange = self.composerTextView.selectedRange;
    NSString *selection = [self.composerTextView.text substringWithRange:selectedRange];
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

- (void)pasteURL
{
    // TODO grab reply text box selection.
    // Wrap [url=url-from-pasteboard]...[/url] around it.
    // if no selection, put cursor inside tag.
    NSURL *copiedURL = [UIPasteboard generalPasteboard].URL;
    if (!copiedURL) {
        copiedURL = [NSURL URLWithString:[UIPasteboard generalPasteboard].string];
    }
    NSString *tag = [NSString stringWithFormat:@"[url=%@]", copiedURL.absoluteString];
    [self wrapSelectionInTag:tag];
}

- (void)insertImage
{
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
    
    [self configureImageSourceSubmenuItems];
    [self showSubmenuThenResetToTopLevelMenuOnHide];
}

- (void)insertEmoticon
{
}

- (CGRect)selectedTextRect
{
    UITextRange *selection = self.composerTextView.selectedTextRange;
    CGRect startRect = [self.composerTextView caretRectForPosition:selection.start];
    CGRect endRect = [self.composerTextView caretRectForPosition:selection.end];
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
                                            inView:self.composerTextView
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

- (void)formatSelectionWithTag:(NSString*)tagful
{/*
  if(!RICH_TEXT_EDITOR_SUPPORT) {
  [self wrapSelectionInTag:tag];
  return;
  }
  
  //UITextView seems to lose custom attributes :(
  //so need to keep own copy
  if (!self.attributedString)
  self.attributedString = [self.composerTextView.attributedText mutableCopy];
  
  [self.attributedString setAttributes:[NSDictionary attributeDictionaryWithTag:tag]
  range:self.composerTextView.selectedRange];
  
  self.composerTextView.attributedText = self.attributedString;
  
  NSLog(@"BBCode version:%@", self.attributedString.BBCode);
  return;
  */
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
    NSRange range = self.composerTextView.selectedRange;
    NSString *selection = [self.composerTextView.text substringWithRange:range];
    NSString *tagged = [NSString stringWithFormat:@"%@%@%@", tag, selection, closingTag];
    [self.composerTextView replaceRange:self.composerTextView.selectedTextRange withText:tagged];
    NSRange equalsSign = [tag rangeOfString:@"="];
    if (equalsSign.location == NSNotFound && ![tag hasSuffix:@"\n"]) {
        self.composerTextView.selectedRange = NSMakeRange(range.location + [tag length], range.length);
    } else {
        self.composerTextView.selectedRange = NSMakeRange(range.location + equalsSign.location + 1, 0);
    }
    [self.composerTextView becomeFirstResponder];
}

- (void)didChooseEmoticon:(AwfulEmoticon *)emoticon {
    //[self.replyTextView insertText:emoticon.code];
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
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
    
    _composerTextView = [AwfulComposerView new];
    _composerTextView.delegate = self;
    //AwfulKeyboardBar *bbcodeBar = [[AwfulKeyboardBar alloc] initWithFrame:
     //                              CGRectMake(0, 0, CGRectGetWidth(self.composerTextView.bounds),
     //                                         UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 63 : 36)];
    //bbcodeBar.characters = @[ @"[", @"=", @":", @"/", @"]" ];
    //bbcodeBar.keyInputView = self.composerTextView;
    //self.composerTextView.inputAccessoryView = bbcodeBar;
    //self.view.backgroundColor = [UIColor blueColor];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    
    CGRect frame = self.view.frame;
    frame.origin.y = 0;
    self.composerTextView.frame = frame;
    self.composerTextView.autoresizingMask = UIViewAutoresizingFlexibleHeight|UIViewAutoresizingFlexibleWidth;
    
    //[self.view addSubview:self.composerTextView];
    [PSMenuItem installMenuHandlerForObject:self.composerTextView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self configureTopLevelMenuItems];
    [self retheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(currentThemeChanged:)
                                                 name:AwfulThemeDidChangeNotification
                                               object:nil];
    self.composerTextView.userInteractionEnabled = YES;
    
    self.composerTextView.text = @"Ut nulla. Vivamus bibendum, nulla ut congue fringilla, lorem ipsum ultricies risus, ut rutrum velit tortor vel purus. In hac habitasse platea dictumst. Duis fermentum, metus sed congue gravida, arcu dui ornare urna, ut imperdiet enim odio dignissim ipsum. Nulla facilisi. Cras magna ante, bibendum sit amet, porta vitae, laoreet ut, justo. Nam tortor sapien, pulvinar nec, malesuada in, ultrices in, tortor. Cras ultricies placerat eros. Quisque odio eros, feugiat non, iaculis nec, lobortis sed, arcu. Pellentesque sit amet sem et purus pretium consectetuer.";
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.composerTextView becomeFirstResponder];
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
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        //[self loadTextView];
    }
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
        [self.composerTextView replaceRange:self.composerTextView.selectedTextRange
                                   withText:ImageKeyToPlaceholder(key, shouldThumbnail)];
    }
    if (self.pickerPopover) {
        [self.pickerPopover dismissPopoverAnimated:YES];
        self.pickerPopover = nil;
    } else {
        [picker dismissViewControllerAnimated:YES completion:nil];
    }
    [self.composerTextView becomeFirstResponder];
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
    [self.composerTextView replaceRange:self.composerTextView.selectedTextRange
                            withText:ImageKeyToPlaceholder(key, shouldThumbnail)];
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
    [self.composerTextView becomeFirstResponder];
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
    [self.composerTextView becomeFirstResponder];
}

@end
