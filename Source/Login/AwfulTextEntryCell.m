//  AwfulTextEntryCell.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTextEntryCell.h"

@implementation AwfulTextEntryCell

#pragma mark - Init

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:reuseIdentifier];
    if (self) {
        UITextField *textField = [UITextField new];
        textField.font = [UIFont systemFontOfSize:17];
        textField.textColor = [UIColor colorWithHue:0.606 saturation:0.450 brightness:0.549 alpha:1];
        [self.contentView addSubview:textField];
        _textField = textField;
    }
    return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style
    reuseIdentifier:(NSString *)reuseIdentifier
{
    return [self initWithReuseIdentifier:reuseIdentifier];
}

#pragma mark - UIView

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect labelFrame = self.textLabel.frame;
    labelFrame.size.width = 100;
    self.textLabel.frame = labelFrame;
    [self.textField sizeToFit];
    CGRect textFieldFrame = self.textField.frame;
    textFieldFrame.origin.x = CGRectGetMaxX(labelFrame) + 5;
    textFieldFrame.origin.y = (self.contentView.bounds.size.height - textFieldFrame.size.height) / 2;
    textFieldFrame.size.width = self.contentView.bounds.size.width - textFieldFrame.origin.x - labelFrame.origin.x;
    self.textField.frame = textFieldFrame;
}

@end
