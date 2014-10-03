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

@implementation SmilieBacktoworkButton

ImplementFrameworkButton(@"emot-backtowork")

@end

@implementation SmilieDeleteButton

ImplementFrameworkButton(@"delete")

@end

@implementation SmilieNextKeyboardButton

ImplementFrameworkButton(@"next_keyboard")

@end

@implementation SmilieRecentsButton

ImplementFrameworkButton(@"recents")

@end
