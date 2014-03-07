//  AwfulPageSettingsView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPageSettingsView.h"

@implementation AwfulPageSettingsView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _avatarsLabel = [UILabel new];
    _avatarsLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_avatarsLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
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
    
    _themeLabel = [UILabel new];
    _themeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_themeLabel setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisHorizontal];
    _themeLabel.text = @"Theme";
    [self addSubview:_themeLabel];
    
    _themePicker = [AwfulThemePicker new];
    _themePicker.translatesAutoresizingMaskIntoConstraints = NO;
    [_themePicker setContentHuggingPriority:UILayoutPriorityDefaultHigh forAxis:UILayoutConstraintAxisVertical];
    [self addSubview:_themePicker];
    
    NSDictionary *views = @{ @"avatarsLabel": _avatarsLabel,
                             @"avatarsSwitch": _avatarsEnabledSwitch,
                             @"imagesLabel": _imagesLabel,
                             @"imagesSwitch": _imagesEnabledSwitch,
                             @"themeLabel": _themeLabel,
                             @"themePicker": _themePicker };
    NSDictionary *metrics = @{ @"hspace": @(innerMargins.width),
                               @"vspace": @(innerMargins.height),
                               @"hmargin": @(outerMargins.width),
                               @"vmargin": @(outerMargins.height) };
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-hmargin-[avatarsLabel(>=themeLabel)]-hspace-[avatarsSwitch]-(>=1)-[imagesLabel]-hspace-[imagesSwitch]-hmargin-|"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:metrics
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-hmargin-[themeLabel(>=avatarsLabel)]-hspace-[themePicker]-hmargin-|"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:metrics
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-vmargin-[avatarsSwitch]-vspace-[themePicker]-vmargin-|"
                                             options:0
                                             metrics:metrics
                                               views:views]];
    
    return self;
}

static const CGSize outerMargins = {32, 20};
static const CGSize innerMargins = {8, 18};

- (CGSize)intrinsicContentSize
{
    CGSize switchSize = _avatarsEnabledSwitch.intrinsicContentSize;
    CGSize themePickerSize = _themePicker.intrinsicContentSize;
    return CGSizeMake(UIViewNoIntrinsicMetric, outerMargins.height * 2 + switchSize.height + innerMargins.height + themePickerSize.height);
}

+ (BOOL)requiresConstraintBasedLayout
{
    return YES;
}

@end
