//  AwfulPageSettingsView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPageSettingsView.h"

@implementation AwfulPageSettingsView
{
    UIView *_titleBackgroundView;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _titleBackgroundView = [UIView new];
    _titleBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_titleBackgroundView];
    
    _titleLabel = [UILabel new];
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _titleLabel.numberOfLines = 0;
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.textColor = [UIColor whiteColor];
    _titleLabel.accessibilityTraits |= UIAccessibilityTraitHeader;
    [_titleBackgroundView addSubview:_titleLabel];
    
    self.titleBackgroundColor = [UIColor colorWithWhite:0.086 alpha:1];
    
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
    
    NSDictionary *views = @{ @"titleLabel": _titleLabel,
                             @"titleBackground": _titleBackgroundView,
                             @"avatarsLabel": _avatarsLabel,
                             @"avatarsSwitch": _avatarsEnabledSwitch,
                             @"imagesLabel": _imagesLabel,
                             @"imagesSwitch": _imagesEnabledSwitch,
                             @"themeLabel": _themeLabel,
                             @"themePicker": _themePicker };
    NSDictionary *metrics = @{ @"hspace": @(innerMargins.width),
                               @"vspace": @(innerMargins.height),
                               @"hmargin": @(outerMargins.width),
                               @"vmargin": @(outerMargins.height),
                               @"titlehmargin": @32,
                               @"titleHeight": @(titleHeight) };
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[titleBackground]-0-|"
                                             options:0
                                             metrics:metrics
                                               views:views]];
    [_titleBackgroundView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-titlehmargin-[titleLabel]-titlehmargin-|"
                                             options:0
                                             metrics:metrics
                                               views:views]];
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
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[titleBackground(titleHeight)]-vmargin-[avatarsSwitch]-vspace-[themePicker]-vmargin-|"
                                             options:0
                                             metrics:metrics
                                               views:views]];
    [_titleBackgroundView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[titleLabel]-0-|"
                                             options:0
                                             metrics:metrics
                                               views:views]];
    
    return self;
}

static const CGSize outerMargins = {32, 20};
static const CGSize innerMargins = {8, 18};
static const CGFloat titleHeight = 38;

- (CGSize)intrinsicContentSize
{
    CGSize switchSize = _avatarsEnabledSwitch.intrinsicContentSize;
    CGSize themePickerSize = _themePicker.intrinsicContentSize;
    CGFloat margins = outerMargins.height * 2 + innerMargins.height;
    return CGSizeMake(UIViewNoIntrinsicMetric, titleHeight + switchSize.height + themePickerSize.height + margins);
}

- (UIColor *)titleBackgroundColor
{
    return _titleBackgroundView.backgroundColor;
}

- (void)setTitleBackgroundColor:(UIColor *)titleBackgroundColor
{
    _titleBackgroundView.backgroundColor = titleBackgroundColor;
    self.titleLabel.backgroundColor = titleBackgroundColor;
}

@end
