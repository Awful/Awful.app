//  AwfulKeyboardBar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulKeyboardBar.h"

@interface AwfulKeyboardButton : UIButton

- (id)initWithString:(NSString *)string;

@property (copy, nonatomic) NSString *string;

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
 */

- (NSString *)getCurrentlyOpenTag:(NSString *)content
{
    // Find start of preceding tag (opener or closer).
    NSUInteger startingBracket = [content rangeOfString:@"[" options:NSBackwardsSearch].location;
    if (startingBracket == NSNotFound) {
        return nil;
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
            // Might be [tag=]
            openerLocation =
                [content rangeOfString:
                 [NSString stringWithFormat:@"[%@=", tagname] options:NSBackwardsSearch].location;
            
            if (openerLocation == NSNotFound) {
                // Never opened, keep searching backwards from the starting bracket.
                return [self getCurrentlyOpenTag:[content substringToIndex:startingBracket]];
            }
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
        // Malformed, fuck 'em.
        return nil;
    }
    
    tagRange.length--; // Omit the ] or =;
    return [content substringWithRange:NSMakeRange(startingBracket + 1, tagRange.location - startingBracket - 1)];
}

static NSCharacterSet * TagNameTerminators(void)
{
    return [NSCharacterSet characterSetWithCharactersInString:@"]="];
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

- (void)keyPressed:(AwfulKeyboardButton *)button
{
    [[UIDevice currentDevice] playInputClick];
    if ([button.string isEqual:@"[/..]"]) {
        [self autocloseBBcode];
    } else {
        [self.textView insertText:button.string];
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
    CGFloat x = floor((CGRectGetWidth(self.bounds) - (width * _buttons.count) - (between * (_buttons.count - 1))) / 2);
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
    
    self.string = string;
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

- (void)setString:(NSString *)string
{
    [self setTitle:string forState:UIControlStateNormal];
}

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
