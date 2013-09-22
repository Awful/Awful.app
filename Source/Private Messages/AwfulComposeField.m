//  AwfulComposeField.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulComposeField.h"

@interface AwfulComposeField ()

@property (nonatomic) UILabel *label;
@property (nonatomic) UITextField *textField;

@end


@implementation AwfulComposeField

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _label = [UILabel new];
    _label.font = [UIFont systemFontOfSize:16];
    [self addSubview:_label];
    _textField = [UITextField new];
    _textField.font = [UIFont systemFontOfSize:16];
    [self addSubview:_textField];
    return self;
}

- (void)layoutSubviews
{
    self.label.frame = (CGRect){ .size.height = CGRectGetHeight(self.frame) - 1 };
    [self.label sizeToFit];
    self.label.center = CGPointMake(0, CGRectGetHeight(self.frame) / 2);
    CGRect labelFrame = self.label.frame;
    labelFrame.origin.x = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 19 : 8;
    self.label.frame = labelFrame;
    CGRect textFieldFrame = self.textField.frame;
    textFieldFrame.origin.y = labelFrame.origin.y;
    textFieldFrame.origin.x = CGRectGetMaxX(labelFrame) + 11;
    textFieldFrame.size.width = CGRectGetWidth(self.frame) - CGRectGetMinX(textFieldFrame);
    textFieldFrame.size.height = labelFrame.size.height;
    self.textField.frame = textFieldFrame;
}

@end
