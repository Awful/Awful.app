//  KeyboardBar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "KeyboardBar.h"
#import "CloseBBcodeTagCommand.h"
#import "Awful-Swift.h"
@import Smilies;

@interface KeyboardButton : SmilieButton

@end

@interface KeyboardBar ()

@property (strong, nonatomic) KeyboardButton *smilieButton;
@property (strong, nonatomic) ShowSmilieKeyboardCommand *smilieCommand;

@property (copy, nonatomic) NSArray *middleButtons;
@property (strong, nonatomic) UIView *middleButtonContainer;

@property (strong, nonatomic) KeyboardButton *autocloseButton;
@property (strong, nonatomic) CloseBBcodeTagCommand *autocloseCommand;

@property (assign, nonatomic) BOOL didAddConstraints;

@end

@implementation KeyboardBar

- (void)dealloc
{
    [_autocloseCommand removeObserver:self forKeyPath:@"enabled" context:KVOContext];
}

- (instancetype)initWithFrame:(CGRect)frame textView:(UITextView *)textView
{
    if ((self = [super initWithFrame:frame inputViewStyle:UIInputViewStyleDefault])) {
        _textView = textView;
        
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
        
        _smilieCommand = [[ShowSmilieKeyboardCommand alloc] initWithTextView:textView];
        
        _autocloseCommand = [[CloseBBcodeTagCommand alloc] initWithTextView:textView];
        [_autocloseCommand addObserver:self forKeyPath:@"enabled" options:(NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew) context:KVOContext];
        
        [self updateColors];
    }
    return self;
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

- (void)didTapSmilieButton
{
    [[UIDevice currentDevice] playInputClick];
    [self.smilieCommand execute];
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

- (void)didTapAutocloseButton
{
    [[UIDevice currentDevice] playInputClick];
    [self.autocloseCommand execute];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == KVOContext) {
        if (object == self.autocloseCommand && [keyPath isEqualToString:@"enabled"]) {
            self.autocloseButton.enabled = [change[NSKeyValueChangeNewKey] boolValue];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

static void * KVOContext = &KVOContext;

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

#pragma mark - UIInputViewAudioFeedback

- (BOOL)enableInputClicksWhenVisible
{
    return YES;
}

@end

@implementation KeyboardButton

- (instancetype)initWithFrame:(CGRect)frame
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
