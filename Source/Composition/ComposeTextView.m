//  ComposeTextView.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ComposeTextView.h"
#import "CompositionInputAccessoryView.h"
#import "Awful-Swift.h"

@interface ComposeTextView () <CompositionHidesMenuItems>

@property (strong, nonatomic) CompositionInputAccessoryView *BBcodeBar;

@end

@implementation ComposeTextView

@synthesize hidesBuiltInMenuItems = _hidesBuiltInMenuItems;

- (CompositionInputAccessoryView *)BBcodeBar
{
    if (!_BBcodeBar) {
        _BBcodeBar = [[CompositionInputAccessoryView alloc] initWithTextView:self];
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
