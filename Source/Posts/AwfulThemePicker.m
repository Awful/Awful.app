//  AwfulThemePicker.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThemePicker.h"
#import "AwfulThemeButton.h"

@implementation AwfulThemePicker

- (void)setSelectedThemeIndex:(NSInteger)index
{
    if (_selectedThemeIndex == index) return;
    if (_selectedThemeIndex != UISegmentedControlNoSegment) {
        UIButton *wasSelected = self.subviews[_selectedThemeIndex];
        wasSelected.selected = NO;
    }
    _selectedThemeIndex = index;
    if (index != UISegmentedControlNoSegment) {
        UIButton *nowSelected = self.subviews[index];
        nowSelected.selected = YES;
    }
}

- (void)insertThemeWithColor:(UIColor *)color atIndex:(NSInteger)index
{
    AwfulThemeButton *button = [AwfulThemeButton new];
    button.backgroundColor = color;
    button.accessibilityLabel = color.accessibilityLabel;
    [button addTarget:self action:@selector(didTapThemeButton:)
     forControlEvents:UIControlEventTouchUpInside];
    if (index > (NSInteger)[self.subviews count]) {
        index = [self.subviews count];
    }
    [self insertSubview:button atIndex:index];
    [self setNeedsLayout];
}

- (void)didTapThemeButton:(UIButton *)button
{
    self.selectedThemeIndex = [self.subviews indexOfObject:button];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _selectedThemeIndex = UISegmentedControlNoSegment;
    return self;
}

- (void)layoutSubviews
{
    NSInteger buttonCount = [self.subviews count];
    NSInteger separatorCount = buttonCount - 1;
    const CGFloat separation = 8;
    CGFloat buttonWidth = floorf((CGRectGetWidth(self.bounds) - separation * separatorCount) / buttonCount);
    CGFloat x = 0;
    CGFloat y = CGRectGetMidY(self.bounds) - CGRectGetHeight([[self.subviews lastObject] bounds]) / 2;
    for (NSInteger i = 0; i < buttonCount; i++) {
        UIView *subview = self.subviews[i];
        subview.frame = CGRectMake(x, y, buttonWidth, CGRectGetHeight(subview.bounds));
        x += buttonWidth + separation;
    }
}

@end
