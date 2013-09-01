//  AwfulNeedPlatinumView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNeedPlatinumView.h"

@implementation AwfulNeedPlatinumView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.headerLabel = [UILabel new];
    self.headerLabel.font = [UIFont systemFontOfSize:28];
    self.headerLabel.textAlignment = NSTextAlignmentCenter;
    [self addSubview:self.headerLabel];
    self.explanationLabel = [UILabel new];
    self.explanationLabel.textAlignment = NSTextAlignmentCenter;
    self.explanationLabel.numberOfLines = 0;
    [self addSubview:self.explanationLabel];
    return self;
}

- (void)layoutSubviews
{
    CGRect inset = CGRectInset(self.bounds, 20, 3);
    self.headerLabel.frame = CGRectMake(0, 0, CGRectGetWidth(inset), 0);
    [self.headerLabel sizeToFit];
    self.explanationLabel.frame = CGRectMake(0, 0, CGRectGetWidth(inset), 0);
    [self.explanationLabel sizeToFit];
    CGRect headerFrame = self.headerLabel.frame;
    headerFrame.origin.x = CGRectGetMidX(inset) - CGRectGetWidth(headerFrame) / 2;
    headerFrame.origin.y = CGRectGetHeight(inset) * 2 / 5;
    self.headerLabel.frame = CGRectIntegral(headerFrame);
    CGRect explanationFrame = self.explanationLabel.frame;
    explanationFrame.origin.x = CGRectGetMidX(inset) - CGRectGetWidth(explanationFrame) / 2;
    explanationFrame.origin.y = CGRectGetMaxY(headerFrame) + 10;
    self.explanationLabel.frame = CGRectIntegral(explanationFrame);
}

@end
