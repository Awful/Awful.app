//  NeedsFullAccessView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NeedsFullAccessView.h"
#import "KeyboardViewController.h"

@interface NeedsFullAccessView ()

@property (nonatomic) UITapGestureRecognizer *tap;

@end

@implementation NeedsFullAccessView

+ (instancetype)newFromNibWithOwner:(KeyboardViewController *)owner
{
    return [[NSBundle bundleForClass:[NeedsFullAccessView class]] loadNibNamed:@"NeedsFullAccessView" owner:owner options:nil][0];
}

- (void)awakeFromNib
{
    self.tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTap:)];
    [self.textView addGestureRecognizer:self.tap];
}

- (void)didTap:(UITapGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateEnded) {
        if (self.tapAction) {
            self.tapAction();
        }
    }
}

@end
