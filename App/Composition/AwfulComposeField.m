//  AwfulComposeField.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulComposeField.h"

@implementation AwfulComposeField

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        _label = [UILabel new];
        _label.translatesAutoresizingMaskIntoConstraints = NO;
        _label.font = [UIFont systemFontOfSize:16];
        [_label setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
        [_label setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
        [self addSubview:_label];
        _textField = [UITextField new];
        _textField.translatesAutoresizingMaskIntoConstraints = NO;
        _textField.font = [UIFont systemFontOfSize:16];
        [self addSubview:_textField];
        NSDictionary *views = @{ @"label": _label,
                                 @"textField": _textField };
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-4-[label]-[textField]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[label]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
        [self addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|[textField]|"
                                                 options:0
                                                 metrics:nil
                                                   views:views]];
    }
    return self;
}

@end
