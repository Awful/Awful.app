//  KeyboardBar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "KeyboardBar.h"
@import Smilies;

@interface KeyboardButton : SmilieButton

@end

@interface KeyboardBar ()

@property (strong, nonatomic) KeyboardButton *smilieButton;
@property (copy, nonatomic) NSArray *middleButtons;
@property (strong, nonatomic) UIView *middleButtonContainer;
@property (strong, nonatomic) KeyboardButton *autocloseButton;

@property (assign, nonatomic) BOOL didAddConstraints;

@end

@implementation KeyboardBar

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame inputViewStyle:UIInputViewStyleDefault])) {
        self.opaque = YES;
        
        self.smilieButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.smilieButton];
        
        self.middleButtonContainer = [UIView new];
        self.middleButtonContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.middleButtonContainer];
        for (UIView *button in self.middleButtons) {
            button.translatesAutoresizingMaskIntoConstraints = NO;
            [self.middleButtonContainer addSubview:button];
        }
        
        self.autocloseButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.autocloseButton];
        
        [self updateColors];
    }
    return self;
}

- (void)setTextView:(UITextView *)textView
{
    if (_textView) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:_textView];
    }
    _textView = textView;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(textViewTextDidChange:)
                                                 name:UITextViewTextDidChangeNotification
                                               object:textView];
    [self updateAutocloseButtonState];
}

- (void)setKeyboardAppearance:(UIKeyboardAppearance)keyboardAppearance
{
    _keyboardAppearance = keyboardAppearance;
    [self updateColors];
}

- (KeyboardButton *)smilieButton
{
    if (!_smilieButton) {
        _smilieButton = [KeyboardButton new];
        [_smilieButton setTitle:@":-)" forState:UIControlStateNormal];
        _smilieButton.accessibilityLabel = @"Toggle smilie keyboard";
        [_smilieButton addTarget:self action:@selector(didTapSmilieButton) forControlEvents:UIControlEventTouchUpInside];
    }
    return _smilieButton;
}

- (NSArray *)middleButtons
{
    if (!_middleButtons) {
        NSMutableArray *buttons = [NSMutableArray new];
        for (NSString *string in @[@"[", @"=", @":", @"/", @"]"]) {
            KeyboardButton *button = [KeyboardButton new];
            [button setTitle:string forState:UIControlStateNormal];
            [button addTarget:self action:@selector(didPressSingleCharacterKey:) forControlEvents:UIControlEventTouchUpInside];
            [buttons addObject:button];
        }
        _middleButtons = buttons;
    }
    return _middleButtons;
}

- (KeyboardButton *)autocloseButton
{
    if (!_autocloseButton) {
        _autocloseButton = [KeyboardButton new];
        [_autocloseButton setTitle:@"[/..]" forState:UIControlStateNormal];
        _autocloseButton.accessibilityLabel = @"Close tag";
        [_autocloseButton setTitleColor:[UIColor grayColor] forState:UIControlStateDisabled];
        [_autocloseButton addTarget:self action:@selector(didTapAutocloseButton) forControlEvents:UIControlEventTouchUpInside];
    }
    return _autocloseButton;
}

- (void)textViewTextDidChange:(NSNotification *)notification
{
    [self updateAutocloseButtonState];
}

- (void)didTapSmilieButton
{
    [self.delegate toggleSmilieKeyboardForKeyboardBar:self];
}

- (void)didTapAutocloseButton
{
    [[UIDevice currentDevice] playInputClick];
    [self autocloseBBcode];
}

- (void)updateAutocloseButtonState
{
    NSString *textContent = [self.textView.text substringToIndex:self.textView.selectedRange.location];
    self.autocloseButton.enabled = [self getCurrentlyOpenTag:textContent] != nil;
}

- (void)didPressSingleCharacterKey:(KeyboardButton *)button
{
    [[UIDevice currentDevice] playInputClick];
    [self.textView insertText:button.currentTitle];
}

- (void)updateColors
{
    void (^setButtonColors)(KeyboardButton *);
    if (self.keyboardAppearance == UIKeyboardAppearanceDark) {
        self.backgroundColor = [UIColor colorWithWhite:0.078 alpha:1];
        setButtonColors = ^(KeyboardButton *button) {
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.normalBackgroundColor = [UIColor colorWithWhite:0.353 alpha:1];
            button.selectedBackgroundColor = [UIColor colorWithWhite:0.149 alpha:1];
            button.layer.shadowColor = [UIColor blackColor].CGColor;
        };
    } else {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.backgroundColor = [UIColor colorWithRed:0.812 green:0.824 blue:0.835 alpha:1];
        } else {
            self.backgroundColor = [UIColor colorWithRed:0.863 green:0.875 blue:0.886 alpha:1];
        }
        setButtonColors = ^(KeyboardButton *button) {
            [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            button.normalBackgroundColor = [UIColor colorWithRed:0.988 green:0.988 blue:0.992 alpha:1];
            button.selectedBackgroundColor = [UIColor colorWithRed:0.831 green:0.839 blue:0.847 alpha:1];
            button.layer.shadowColor = [UIColor grayColor].CGColor;
        };
    }
    
    setButtonColors(self.smilieButton);
    for (KeyboardButton *button in self.middleButtons) {
        setButtonColors(button);
    }
    setButtonColors(self.autocloseButton);
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    [self setNeedsUpdateConstraints];
}

- (void)updateConstraints
{
    if (!self.didAddConstraints) {
        #define PhoneOrPad(a, b) (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad ? (b) : (a))
        CGFloat width = PhoneOrPad(40, 57);
        CGFloat height = PhoneOrPad(32, 57);
        CGFloat between = PhoneOrPad(6, 12);
        #undef PhoneOrPad
        
        // All buttons' height, width, and centerY are keyed off of the autoclose button.
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:[autoclose(width)]-2-|"
                                                 options:0
                                                 metrics:@{@"width": @(width)}
                                                   views:@{@"autoclose": self.autocloseButton}]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-2-[smilie(autoclose)]"
                                                 options:0
                                                 metrics:nil
                                                   views:@{@"smilie": self.smilieButton,
                                                           @"autoclose": self.autocloseButton}]];
        [self.autocloseButton addConstraint:
         [NSLayoutConstraint constraintWithItem:self.autocloseButton
                                      attribute:NSLayoutAttributeHeight
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:nil
                                      attribute:NSLayoutAttributeNotAnAttribute
                                     multiplier:0
                                       constant:height]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:self.smilieButton
                                      attribute:NSLayoutAttributeHeight
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.autocloseButton
                                      attribute:NSLayoutAttributeHeight
                                     multiplier:1
                                       constant:0]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:self.autocloseButton
                                      attribute:NSLayoutAttributeCenterY
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self
                                      attribute:NSLayoutAttributeCenterY
                                     multiplier:1
                                       constant:0]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:self.smilieButton
                                      attribute:NSLayoutAttributeCenterY
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.autocloseButton
                                      attribute:NSLayoutAttributeCenterY
                                     multiplier:1
                                       constant:0]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:self.middleButtonContainer
                                      attribute:NSLayoutAttributeCenterX
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self
                                      attribute:NSLayoutAttributeCenterX
                                     multiplier:1
                                       constant:0]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:self.middleButtonContainer
                                      attribute:NSLayoutAttributeHeight
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.autocloseButton
                                      attribute:NSLayoutAttributeHeight
                                     multiplier:1
                                       constant:0]];
        [self addConstraint:
         [NSLayoutConstraint constraintWithItem:self.middleButtonContainer
                                      attribute:NSLayoutAttributeCenterY
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.autocloseButton
                                      attribute:NSLayoutAttributeCenterY
                                     multiplier:1
                                       constant:0]];
        
        [self.middleButtonContainer addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[first(width)]"
                                                 options:0
                                                 metrics:@{@"width": @(width)}
                                                   views:@{@"first": self.middleButtons.firstObject,
                                                           @"autoclose": self.autocloseButton}]];
        [self.middleButtonContainer addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[first]|"
                                                 options:0
                                                 metrics:nil
                                                   views:@{@"first": self.middleButtons.firstObject}]];
        [self.middleButtonContainer addConstraint:
         [NSLayoutConstraint constraintWithItem:self.middleButtons.lastObject
                                      attribute:NSLayoutAttributeRight
                                      relatedBy:NSLayoutRelationEqual
                                         toItem:self.middleButtonContainer
                                      attribute:NSLayoutAttributeRight
                                     multiplier:1
                                       constant:0]];
        for (NSUInteger i = 1; i < self.middleButtons.count; i++) {
            [self.middleButtonContainer addConstraints:
             [NSLayoutConstraint constraintsWithVisualFormat:@"H:[left]-between-[right(width)]"
                                                     options:0
                                                     metrics:@{@"between": @(between),
                                                               @"width": @(width)}
                                                       views:@{@"left": self.middleButtons[i - 1],
                                                               @"right": self.middleButtons[i],
                                                               @"autoclose": self.autocloseButton}]];
            [self.middleButtonContainer addConstraints:
             [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[right]|"
                                                     options:0
                                                     metrics:nil
                                                       views:@{@"right": self.middleButtons[i]}]];
        }
        
        self.didAddConstraints = YES;
    }
    [super updateConstraints];
}

#pragma mark - Autoclosing BBcode tags

/*
 * Insert the appropriate closing tag, if any.
 *
 * First, scan backwards for [code]. If so, and there's no [/code] between there and here, then
 * the insertion is always [/code] (bbcode within [code] isn't interpreted).
 *
 * Scan backwards looking for [.
 * - If we find a [/tag], scan backwards for its [tag] and continue search from there.
 * - If we find [tag], trim =part if any, and insert [/tag].
 *
 * XXX should have a list of bbcode tags, and only consider those?
 */

/* Tests:
 * "[code] [b]"                -> TRUE
 * "[code] [b] [/code]"        -> FALSE
 * "[code] [b] [/code][code]"  -> TRUE
 * "[code=cpp] [b]"            -> TRUE
 * "[/code]"                   -> FALSE
 * "[codemonkey] [b]"          -> FALSE
 * "[code][codemonkey]"        -> TRUE
 */
 - (BOOL)hasOpenCodeTag:(NSString *)content
{
    NSRange codeRange = [content rangeOfString:@"[code" options:NSBackwardsSearch];
    if (codeRange.location == NSNotFound || NSMaxRange(codeRange) >= content.length) {
        return NO;
    }
    
    // If it's a false alarm like [codemonkey], keep looking.
    unichar nextChar = [content characterAtIndex:NSMaxRange(codeRange) /* [code */];
    if (![TagNameTerminators() characterIsMember:nextChar]) {
        return [self hasOpenCodeTag:[content substringToIndex:codeRange.location]];
    }
    
    // Is this still open?
    return [[content substringFromIndex:codeRange.location] rangeOfString:@"[/code]"].location == NSNotFound;
}

/*
 * Tests:
 * "[b][i]"              -> "i"
 * "[b][i][/i]"          -> "b"
 * "[b][/b]"             -> nil
 * "[url=foo]"           -> "url"
 * "[url=foo][b][i][/b]" -> "url"
 * "["                   -> "nil"
 * "[foo][/x"            -> "foo"
 * "[foo attr]"          -> "foo"
 * "[code][b]"           -> "code"
 * "[b][code][/code]"    -> "b"
 * "[list][*]"           -> "list"
 */

- (NSString *)getCurrentlyOpenTag:(NSString *)content
{
    // Find start of preceding tag (opener or closer).
    NSUInteger startingBracket = [content rangeOfString:@"[" options:NSBackwardsSearch].location;
    if (startingBracket == NSNotFound) {
        return nil;
    }
    
    if (startingBracket >= content.length - 1) {
        // Incomplete tag, keep going.
        return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
    }
    
    // If it's a closer, find its opener.
    if ([content characterAtIndex:(startingBracket + 1)] == '/') {
        NSRange tagRange = [[content substringFromIndex:startingBracket] rangeOfString:@"]"];
        if (tagRange.location == NSNotFound) {
            // Not a proper tag, keep searching backwards.
            return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
        }
        
        tagRange = NSMakeRange(startingBracket + 2, tagRange.location - 2);
        NSString *tagname = [content substringWithRange:tagRange];
        
        NSUInteger openerLocation =
            [content rangeOfString:
             [NSString stringWithFormat:@"[%@]", tagname] options:NSBackwardsSearch].location;

        if (openerLocation == NSNotFound) {
            // Might be [tag=attr]
            openerLocation =
                [content rangeOfString:
                 [NSString stringWithFormat:@"[%@=", tagname] options:NSBackwardsSearch].location;
        }

        if (openerLocation == NSNotFound) {
            // Might be [tag attr=val]
            openerLocation =
            [content rangeOfString:
             [NSString stringWithFormat:@"[%@ ", tagname] options:NSBackwardsSearch].location;
        }
            
        if (openerLocation == NSNotFound) {
            // Never opened, keep searching backwards from the starting bracket.
            return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
        }
        
        // Now that we've matched [tag]...[/tag], keep looking back for an outer [tag2] that
        // might still be open.
        return [self getCurrentlyOpenTag:[content substringToIndex:openerLocation]];
    }
    
    // We have an opener! Find the end of the tag name.
    NSRange tagRange = [content rangeOfCharacterFromSet:TagNameTerminators()
                                                options:0
                                                  range:NSMakeRange(startingBracket + 1, content.length - startingBracket - 1)];
    if (tagRange.location == NSNotFound) {
        // Malformed, keep looking.
        return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
    }
    
    tagRange.length--; // Omit the ] or =;
    NSString *tagName = [content substringWithRange:NSMakeRange(startingBracket + 1, tagRange.location - startingBracket - 1)];
    if ([tagName isEqualToString:@"*"]) {
        return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
    }
    
    return tagName;
}

static NSCharacterSet * TagNameTerminators(void)
{
    return [NSCharacterSet characterSetWithCharactersInString:@"]= "];
}

- (void)autocloseBBcode
{
    NSString *textContent = [self.textView.text substringToIndex:self.textView.selectedRange.location];
    
    if ([self hasOpenCodeTag:textContent]) {
        [self.textView insertText:@"[/code]"];
        return;
    }
    
    NSString *openTag = [self getCurrentlyOpenTag:textContent];
    if (openTag) {
        [self.textView insertText:[NSString stringWithFormat:@"[/%@]", openTag]];
    }
}

#pragma mark - UIInputViewAudioFeedback

- (BOOL)enableInputClicksWhenVisible
{
    return YES;
}

@end

@implementation KeyboardButton

- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:22];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            self.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 5, 0);
        }
        self.layer.cornerRadius = 4;
        self.layer.borderWidth = 0;
        self.layer.shadowOpacity = 1;
        self.layer.shadowOffset = CGSizeMake(0, 1);
        self.layer.shadowRadius = 0;
        self.accessibilityTraits &= ~UIAccessibilityTraitButton;
        self.accessibilityTraits |= UIAccessibilityTraitKeyboardKey;
    }
    return self;
}

@end
