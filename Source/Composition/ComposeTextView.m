//  ComposeTextView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ComposeTextView.h"
#import "KeyboardBar.h"
#import "Awful-Swift.h"

@interface ComposeTextView () <CompositionHidesMenuItems>

@property (strong, nonatomic) KeyboardBar *BBcodeBar;

@end

@implementation ComposeTextView

@synthesize hidesBuiltInMenuItems = _hidesBuiltInMenuItems;

- (KeyboardBar *)BBcodeBar
{
    if (!_BBcodeBar) {
        CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds),
                                  UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 66 : 38);
        _BBcodeBar = [[KeyboardBar alloc] initWithFrame:frame textView:self];
        _BBcodeBar.keyboardAppearance = self.keyboardAppearance;
    }
    return _BBcodeBar;
}

#pragma mark - UITextInputTraits

- (void)setKeyboardAppearance:(UIKeyboardAppearance)keyboardAppearance
{
    [super setKeyboardAppearance:keyboardAppearance];
    _BBcodeBar.keyboardAppearance = keyboardAppearance;
}

#pragma mark - UIResponder

- (BOOL)becomeFirstResponder
{
    self.inputAccessoryView = self.BBcodeBar;
    if (![super becomeFirstResponder]) {
        self.inputAccessoryView = nil;
        return NO;
    }
    return YES;
}

- (BOOL)resignFirstResponder
{
    if (![super resignFirstResponder]) return NO;
    self.inputAccessoryView = nil;
    return YES;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
    return !self.hidesBuiltInMenuItems && [super canPerformAction:action withSender:sender];
}

@end

const CGSize RequiresThumbnailImageSize = {800, 600};
