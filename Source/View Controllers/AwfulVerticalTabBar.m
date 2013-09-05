//
//  AwfulVerticalTabBar.m
//  Awful
//
//  Created by Nolan Waite on 2013-09-05.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulVerticalTabBar.h"

@implementation AwfulVerticalTabBar
{
    NSMutableArray *_buttons;
    NSMutableArray *_buttonConstraints;
}

- (id)initWithItems:(NSArray *)items
{
    if (!(self = [super init])) return nil;
    self.items = items;
    _buttons = [NSMutableArray new];
    _buttonConstraints = [NSMutableArray new];
    return self;
}

- (void)setItems:(NSArray *)items
{
    if (_items == items) return;
    _items = [items copy];
    while (_items.count < _buttons.count) {
        UIButton *button = _buttons.lastObject;
        [button removeFromSuperview];
        [_buttons removeLastObject];
    }
    while (_items.count > _buttons.count) {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [self addSubview:button];
        [_buttons addObject:button];
    }
    [self removeConstraints:_buttonConstraints];
    [_buttonConstraints removeAllObjects];
    [self setNeedsUpdateConstraints];
}

- (void)updateConstraints
{
    [super updateConstraints];
    [_buttons enumerateObjectsUsingBlock:^(UITabBarItem *item, NSUInteger i, BOOL *stop) {
        UIButton *button = _buttons[i];
        [button setImage:item.image forState:UIControlStateNormal];
        [_buttonConstraints addObjectsFromArray:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[button]|"
                                                 options:0
                                                 metrics:nil
                                                   views:@{ @"button": button }]];
        if (i == 0) {
            [_buttonConstraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[button]"
                                                     options:0
                                                     metrics:nil
                                                       views:@{ @"button": button }]];
        } else {
            [_buttonConstraints addObjectsFromArray:
             [NSLayoutConstraint constraintsWithVisualFormat:@"V:[top]-4-[bottom]"
                                                     options:0
                                                     metrics:nil
                                                       views:@{ @"top": _buttons[i - 1],
                                                                @"bottom": button }]];
        }
    }];
    [self addConstraints:_buttonConstraints];
}

@end
