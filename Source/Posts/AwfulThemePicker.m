//  AwfulThemePicker.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThemePicker.h"
#import "AwfulThemeButton.h"

@implementation AwfulThemePicker
{
    NSMutableArray *_buttons;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _selectedThemeIndex = UISegmentedControlNoSegment;
    _buttons = [NSMutableArray new];
    
    return self;
}

- (void)setSelectedThemeIndex:(NSInteger)index
{
    if (_selectedThemeIndex == index) return;
    if (_selectedThemeIndex != UISegmentedControlNoSegment) {
        UIButton *wasSelected = _buttons[_selectedThemeIndex];
        wasSelected.selected = NO;
    }
    _selectedThemeIndex = index;
    if (index != UISegmentedControlNoSegment) {
        UIButton *nowSelected = _buttons[index];
        nowSelected.selected = YES;
    }
}

- (void)insertThemeWithColor:(UIColor *)color atIndex:(NSInteger)index
{
    AwfulThemeButton *button = [[AwfulThemeButton alloc] initWithThemeColor:color];
    [button addTarget:self action:@selector(didTapThemeButton:) forControlEvents:UIControlEventTouchUpInside];
    if (index > (NSInteger)self.subviews.count) {
        index = self.subviews.count;
    }
    [self insertSubview:button atIndex:index];
    [_buttons addObject:button];
    [self setNeedsLayout];
}

- (void)setPreferredMaxLayoutWidth:(CGFloat)preferredMaxLayoutWidth
{
    if (_preferredMaxLayoutWidth == preferredMaxLayoutWidth) return;
    _preferredMaxLayoutWidth = preferredMaxLayoutWidth;
    [self invalidateIntrinsicContentSize];
}

- (void)didTapThemeButton:(UIButton *)button
{
    self.selectedThemeIndex = [self.subviews indexOfObject:button];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)layoutSubviews
{
    UIButton *button = _buttons.firstObject;
    CGSize buttonSize = button.intrinsicContentSize;
    
    CGRect bounds = self.bounds;
    CGRect buttonFrame = (CGRect){ .size = buttonSize };
    for (UIButton *button in _buttons) {
        button.frame = buttonFrame;
        buttonFrame.origin.x = margin + CGRectGetMaxX(buttonFrame);
        if (CGRectGetMaxX(buttonFrame) > CGRectGetMaxX(bounds)) {
            buttonFrame.origin.x = 0;
            buttonFrame.origin.y = margin + CGRectGetMaxY(buttonFrame);
        }
    }
}

static const CGFloat margin = 6;

- (CGSize)intrinsicContentSize
{
    NSInteger numberOfButtons = _buttons.count;
    UIButton *firstButton = _buttons.firstObject;
    CGSize buttonSize = firstButton.intrinsicContentSize;
    
    if (self.preferredMaxLayoutWidth <= 0) {
        CGFloat width = buttonSize.width * numberOfButtons + (numberOfButtons - 1) * margin;
        CGSize contentSize = CGSizeMake(width, buttonSize.height);
        return contentSize;
    }
    
    CGFloat maximumWidth = self.preferredMaxLayoutWidth;
    NSAssert(maximumWidth >= buttonSize.width, @"can't lay out theme buttons in a view narrower than a single button");
    CGFloat remainingWidth = maximumWidth - buttonSize.width;
    NSInteger buttonsPerLine = 1 + floor(remainingWidth / (margin + buttonSize.width));
    NSInteger numberOfLines = numberOfButtons / buttonsPerLine;
    if (numberOfButtons % buttonsPerLine > 0) {
        numberOfLines++;
    }
    CGSize contentSize = CGSizeMake(buttonsPerLine * buttonSize.width + (buttonsPerLine - 1) * margin,
                                    numberOfLines * buttonSize.height + (numberOfLines - 1) * margin);
    return contentSize;
}

@end
