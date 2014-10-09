//  SmilieButton.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieButton.h"

@implementation SmilieButton

- (void)setSelectedTintColor:(UIColor *)selectedTintColor
{
    _selectedTintColor = selectedTintColor;
    [self updateTintColor];
}

- (void)updateTintColor
{
    if (self.selected || self.highlighted) {
        self.tintColor = self.selectedTintColor;
    } else {
        self.tintColor = nil;
    }
}

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

- (void)updateBackgroundColor
{
    if (self.selected || self.highlighted) {
        self.backgroundColor = self.selectedBackgroundColor;
    } else {
        self.backgroundColor = self.normalBackgroundColor;
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self updateTintColor];
    [self updateBackgroundColor];
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    [self updateTintColor];
    [self updateBackgroundColor];
}

@end

#define ImplementFrameworkButton(_imageName) \
- (id)initWithCoder:(NSCoder *)coder \
{ \
    if ((self = [super initWithCoder:coder])) { \
        [self loadAndSetNormalImage]; \
    } \
    return self; \
} \
 \
- (instancetype)initWithFrame:(CGRect)frame \
{ \
    if ((self = [super initWithFrame:frame])) { \
        [self loadAndSetNormalImage]; \
    } \
    return self; \
} \
 \
- (void)prepareForInterfaceBuilder \
{ \
    [super prepareForInterfaceBuilder]; \
    [self loadAndSetNormalImage]; \
} \
 \
- (void)loadAndSetNormalImage \
{ \
    [self setImage:FrameworkImageNamed(_imageName) forState:UIControlStateNormal]; \
}

static UIImage * FrameworkImageNamed(NSString *imageName)
{
    NSBundle *frameworkBundle = [NSBundle bundleForClass:[SmilieButton class]];
    return [UIImage imageNamed:imageName inBundle:frameworkBundle compatibleWithTraitCollection:nil];
}

@implementation SmilieDeleteButton

ImplementFrameworkButton(@"delete")

@end

@implementation SmilieFavoriteButton

ImplementFrameworkButton(@"favorite")

@end

@implementation SmilieGridButton

ImplementFrameworkButton(@"grid")

@end

@implementation SmilieNextKeyboardButton

ImplementFrameworkButton(@"next-keyboard")

@end

@implementation SmilieRecentButton

ImplementFrameworkButton(@"recent")

@end
