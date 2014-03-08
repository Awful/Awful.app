//  AwfulJumpToPageView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulJumpToPageView.h"

@implementation AwfulJumpToPageView
{
    UIView *_buttonsBackgroundView;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _buttonsBackgroundView = [UIView new];
    _buttonsBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_buttonsBackgroundView];
    
    _firstPageButton = [UIButton new];
    _firstPageButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_firstPageButton setTitle:@"First Page" forState:UIControlStateNormal];
    [_buttonsBackgroundView addSubview:_firstPageButton];
    
    _jumpButton = [UIButton new];
    _jumpButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_jumpButton setTitle:@"Jump" forState:UIControlStateNormal];
    [_buttonsBackgroundView addSubview:_jumpButton];
    
    _lastPageButton = [UIButton new];
    _lastPageButton.translatesAutoresizingMaskIntoConstraints = NO;
    [_lastPageButton setTitle:@"Last Page" forState:UIControlStateNormal];
    [_buttonsBackgroundView addSubview:_lastPageButton];
    
    _pickerView = [UIPickerView new];
    _pickerView.translatesAutoresizingMaskIntoConstraints = NO;
    _pickerView.showsSelectionIndicator = YES;
    [self addSubview:_pickerView];
    
    NSDictionary *views = @{ @"buttonRow": _buttonsBackgroundView,
                             @"firstPage": _firstPageButton,
                             @"jump": _jumpButton,
                             @"lastPage": _lastPageButton,
                             @"picker": _pickerView };
    NSDictionary *metrics = @{ @"hmargin": @14,
                               @"rowHeight": @(buttonRowHeight),
                               @"pickerHeight": @(pickerHeight) };
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[buttonRow]-0-|"
                                             options:0
                                             metrics:metrics
                                               views:views]];
    [_buttonsBackgroundView addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-hmargin-[firstPage]-(>=1)-[jump]-(>=1)-[lastPage]-hmargin-|"
                                             options:NSLayoutFormatAlignAllCenterY
                                             metrics:metrics
                                               views:views]];
    [_buttonsBackgroundView addConstraint:
     [NSLayoutConstraint constraintWithItem:_jumpButton
                                  attribute:NSLayoutAttributeCenterX
                                  relatedBy:NSLayoutRelationEqual
                                     toItem:_buttonsBackgroundView
                                  attribute:NSLayoutAttributeCenterX
                                 multiplier:1
                                   constant:0]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[picker]-0-|"
                                             options:0
                                             metrics:metrics
                                               views:views]];
    [self addConstraints:
     [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[buttonRow(rowHeight)]-0-[picker(pickerHeight)]-0-|"
                                             options:0
                                             metrics:metrics
                                               views:views]];
    
    return self;
}

- (CGSize)intrinsicContentSize
{
    return CGSizeMake(320, buttonRowHeight + pickerHeight);
}

static const CGFloat buttonRowHeight = 40;
static const CGFloat pickerHeight = 162;

@end
