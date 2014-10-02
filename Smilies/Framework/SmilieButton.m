//  SmilieButton.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieButton.h"

@implementation SmilieButton

- (void)setNormalBackgroundColor:(UIColor *)normalBackgroundColor
{
    _normalBackgroundColor = normalBackgroundColor;
    [self updateBackgroundColor];
}

- (void)setSelectedBackgroundColor:(UIColor *)selectedBackgroundColor
{
    _selectedBackgroundColor = selectedBackgroundColor;
    [self updateBackgroundColor];
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self updateBackgroundColor];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self updateBackgroundColor];
}

- (void)updateBackgroundColor
{
    if (self.state & (UIControlStateSelected | UIControlStateHighlighted)) {
        self.backgroundColor = self.selectedBackgroundColor;
    } else {
        self.backgroundColor = self.normalBackgroundColor;
    }
}

@end

@implementation SmilieNextKeyboardButton

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        CommonInit(self);
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        CommonInit(self);
    }
    return self;
}

static void CommonInit(SmilieNextKeyboardButton *self)
{
    // This doesn't work when running in IB so we'll do it again in -prepareForInterfaceBuilder.
    [self setImage:NextKeyboardImage() forState:UIControlStateNormal];
}

- (void)prepareForInterfaceBuilder
{
    [super prepareForInterfaceBuilder];
    [self setImage:NextKeyboardImage() forState:UIControlStateNormal];
}

static UIImage * NextKeyboardImage(void)
{
    NSBundle *frameworkBundle = [NSBundle bundleForClass:[SmilieButton class]];
    return [UIImage imageNamed:@"next_keyboard" inBundle:frameworkBundle compatibleWithTraitCollection:nil];
}

@end
