//  AwfulThemePicker.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThemePicker.h"
#import "AwfulThemeButton.h"

@implementation AwfulThemePicker
{
    NSMutableArray *_constraints;
}

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _selectedThemeIndex = UISegmentedControlNoSegment;
    _constraints = [NSMutableArray new];
    return self;
}

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
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.backgroundColor = color;
    button.accessibilityLabel = color.accessibilityLabel;
    [button addTarget:self action:@selector(didTapThemeButton:)
     forControlEvents:UIControlEventTouchUpInside];
    if (index > (NSInteger)[self.subviews count]) {
        index = [self.subviews count];
    }
    [self insertSubview:button atIndex:index];
    [self invalidateIntrinsicContentSize];
    [self removeConstraints:_constraints];
    [_constraints removeAllObjects];
    [self setNeedsUpdateConstraints];
}

- (void)didTapThemeButton:(UIButton *)button
{
    self.selectedThemeIndex = [self.subviews indexOfObject:button];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

static const CGFloat Padding = 8;

- (CGSize)intrinsicContentSize
{
    NSUInteger numberOfButtons = self.subviews.count;
    if (numberOfButtons == 0) return CGSizeZero;
    UIView *button = self.subviews.firstObject;
    return CGSizeMake(CGRectGetWidth(button.frame) * numberOfButtons + Padding * (numberOfButtons - 1),
                      CGRectGetHeight(button.frame));
}

- (void)updateConstraints
{
    [super updateConstraints];
    UIView *previous;
    for (UIView *subview in self.subviews) {
        [_constraints addObjectsFromArray:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[subview]|"
                                                 options:0
                                                 metrics:nil
                                                   views:NSDictionaryOfVariableBindings(subview)]];
        if (!previous) {
            [_constraints addObject:
             [NSLayoutConstraint constraintWithItem:subview
                                          attribute:NSLayoutAttributeLeft
                                          relatedBy:NSLayoutRelationEqual
                                             toItem:self
                                          attribute:NSLayoutAttributeLeft
                                         multiplier:1
                                           constant:0]];
        } else {
            [_constraints addObject:
             [NSLayoutConstraint constraintWithItem:subview
                                          attribute:NSLayoutAttributeLeft
                                          relatedBy:NSLayoutRelationEqual
                                             toItem:previous
                                          attribute:NSLayoutAttributeRight
                                         multiplier:1
                                           constant:Padding]];
        }
        previous = subview;
    }
    [self addConstraints:_constraints];
}

@end
