//  AwfulPageSettingsView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPageSettingsView.h"

@implementation AwfulPageSettingsView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    
    _avatarsLabel = [UILabel new];
    _avatarsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _avatarsLabel.text = @"Avatars";
    [self addSubview:_avatarsLabel];
    
    _avatarsEnabledSwitch = [UISwitch new];
    _avatarsEnabledSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_avatarsEnabledSwitch];
    
    _imagesLabel = [UILabel new];
    _imagesLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _imagesLabel.text = @"Images";
    [self addSubview:_imagesLabel];
    
    _imagesEnabledSwitch = [UISwitch new];
    _imagesEnabledSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_imagesEnabledSwitch];
    
    _themePicker = [AwfulThemePicker new];
    _themePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_themePicker];
    
    [self setNeedsUpdateConstraints];
    return self;
}

- (void)updateConstraints
{
    NSDictionary *views = @{ @"avatarsLabel": self.avatarsLabel,
                             @"avatarsSwitch": self.avatarsEnabledSwitch,
                             @"imagesLabel": self.imagesLabel,
                             @"imagesSwitch": self.imagesEnabledSwitch,
                             @"themePicker": self.themePicker };
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[avatarsLabel]-[avatarsSwitch]"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:[imagesLabel]-[imagesSwitch]"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[themePicker]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-12-[avatarsSwitch]-[imagesSwitch]"
                                             options:NSLayoutFormatAlignAllLeft
                                             metrics:nil
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:[imagesSwitch]-[themePicker]"
                                             options:0
                                             metrics:nil
                                               views:views]];
    [super updateConstraints];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    [self layoutIfNeeded];
    CGRect all = self.avatarsLabel.frame;
    for (UIView *subview in self.subviews) {
        all = CGRectUnion(all, subview.frame);
    }
    return CGSizeMake(CGRectGetMaxX(all) + CGRectGetMinX(all),
                      CGRectGetMaxY(all) + CGRectGetMinY(all));
}

@end
