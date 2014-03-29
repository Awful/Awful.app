//  AwfulKeyboardBar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulKeyboardBar.h"

@interface AwfulKeyboardButton : UIButton

- (id)initWithString:(NSString *)string;

@property (readonly, copy, nonatomic) NSString *string;

@property (strong, nonatomic) UIColor *highlightedBackgroundColor;

@end

@implementation AwfulKeyboardBar
{
    NSMutableArray *_buttons;
}

- (void)setStrings:(NSArray *)strings
{
    _strings = [strings copy];
    [_buttons makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [_buttons removeAllObjects];
    for (NSString *string in strings) {
        AwfulKeyboardButton *button = [[AwfulKeyboardButton alloc] initWithString:string];
        [button addTarget:self action:@selector(keyPressed:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:button];
        [_buttons addObject:button];
    }
    [self setNeedsLayout];
}

- (void)autocloseBBcode
{
    NSString *textContent = self.textView.text;

    // Find nearest ] before current cursor point.
    NSUInteger closingBracketPos = [textContent rangeOfString:@"]" options:NSBackwardsSearch
                                        range:NSMakeRange(0, self.textView.selectedRange.location)].location;
    if (closingBracketPos == NSNotFound) {
        return;
    }
    // Find matching [ opener.
    NSUInteger openingBracketPos = [textContent rangeOfString:@"[" options:NSBackwardsSearch
                                                        range:NSMakeRange(0, closingBracketPos)].location;
    if (openingBracketPos == NSNotFound) {
        return;
    }
    // If there's an = in the opener, the tag name ends there.
    NSUInteger equalsPos = [textContent rangeOfString:@"=" options:0
                                                    range:NSMakeRange(openingBracketPos,
                                                                      closingBracketPos - openingBracketPos)].location;
    if (equalsPos != NSNotFound) {
        closingBracketPos = equalsPos;
    }
    [self.keyInputView insertText:@"[/"];
    NSRange bbcodeRange = NSMakeRange(openingBracketPos + 1, closingBracketPos - openingBracketPos - 1);
    [self.keyInputView insertText:[textContent substringWithRange:bbcodeRange]];
    [self.keyInputView insertText:@"]"];
}

- (void)keyPressed:(AwfulKeyboardButton *)button
{
    [[UIDevice currentDevice] playInputClick];
    if ([button.string isEqual:@"[/..]"]) {
        [self autocloseBBcode];
    } else {
        [self.keyInputView insertText:button.string];
    }
}

- (void)setKeyboardAppearance:(UIKeyboardAppearance)keyboardAppearance
{
    _keyboardAppearance = keyboardAppearance;
    [self updateColors];
}

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _buttons = [NSMutableArray new];
    self.opaque = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self updateColors];
    return self;
}

- (void)updateColors
{
    if (self.keyboardAppearance == UIKeyboardAppearanceDark) {
        self.backgroundColor = [UIColor colorWithWhite:0.078 alpha:1];
        for (AwfulKeyboardButton *button in _buttons) {
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.backgroundColor = [UIColor colorWithWhite:0.353 alpha:1];
            button.highlightedBackgroundColor = [UIColor colorWithWhite:0.149 alpha:1];
            button.layer.shadowColor = [UIColor blackColor].CGColor;
        }
    } else {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.backgroundColor = [UIColor colorWithRed:0.812 green:0.824 blue:0.835 alpha:1];
        } else {
            self.backgroundColor = [UIColor colorWithRed:0.863 green:0.875 blue:0.886 alpha:1];
        }
        for (AwfulKeyboardButton *button in _buttons) {
            [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            button.backgroundColor = [UIColor colorWithRed:0.988 green:0.988 blue:0.992 alpha:1];
            button.highlightedBackgroundColor = [UIColor colorWithRed:0.831 green:0.839 blue:0.847 alpha:1];
            button.layer.shadowColor = [UIColor grayColor].CGColor;
        }
    }
}

- (void)layoutSubviews
{
    const CGFloat width = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 57 : 40;
    const CGFloat height = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? width : 32;
    const CGFloat between = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 12 : 6;
    const CGFloat topMargin = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 7 : 2;
    CGFloat x = floorf((CGRectGetWidth(self.bounds) - (width * _buttons.count) - (between * (_buttons.count - 1))) / 2);
    for (UIButton *button in _buttons) {
        button.frame = CGRectMake(x, topMargin, width, height);
        x += width + between;
    }
}

#pragma mark - UIInputViewAudioFeedback

- (BOOL)enableInputClicksWhenVisible
{
    return YES;
}

@end

@implementation AwfulKeyboardButton
{
    UIColor *_normalBackgroundColor;
}

- (id)initWithString:(NSString *)string
{
    self = [super init];
    if (!self) return nil;
    [self setTitle:string forState:UIControlStateNormal];
    self.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:22];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        self.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 5, 0);
    }
    self.layer.cornerRadius = 4;
    self.layer.borderWidth = 0;
    self.layer.shadowOpacity = 1;
    self.layer.shadowOffset = CGSizeMake(0, 1);
    self.layer.shadowRadius = 0;
    return self;
}

- (NSString *)string
{
    return [self titleForState:UIControlStateNormal];
}

#pragma mark - UIButton

- (void)setBackgroundColor:(UIColor *)backgroundColor
{
    [super setBackgroundColor:backgroundColor];
    _normalBackgroundColor = backgroundColor;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    if (highlighted) {
        super.backgroundColor = self.highlightedBackgroundColor;
    } else {
        super.backgroundColor = _normalBackgroundColor;
    }
}

@end
