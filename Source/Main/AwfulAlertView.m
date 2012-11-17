//
//  AwfulAlertView.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-16.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAlertView.h"

@interface AwfulAlertView () <UIAlertViewDelegate>

@property (weak, nonatomic) id <UIAlertViewDelegate> actualDelegate;

@property (readonly, nonatomic) NSMutableDictionary *blocks;

@end

@implementation AwfulAlertView

+ (void)showWithTitle:(NSString *)title
              message:(NSString *)message
          buttonTitle:(NSString *)buttonTitle
           completion:(void (^)(void))block
{
    AwfulAlertView *alert = [[self alloc] initWithTitle:title];
    alert.message = message;
    alert.blocks[@(alert.numberOfButtons)] = [block copy];
    [alert addButtonWithTitle:buttonTitle];
    [alert show];
}

+ (void)showWithTitle:(NSString *)title
                error:(NSError *)error
          buttonTitle:(NSString *)buttonTitle
           completion:(void (^)(void))block
{
    NSString *message = [NSString stringWithFormat:@"%@ (error code %@)",
                         [error localizedDescription], @([error code])];
    [self showWithTitle:title message:message buttonTitle:buttonTitle completion:block];
}

+ (void)showWithTitle:(NSString *)title error:(NSError *)error buttonTitle:(NSString *)buttonTitle
{
    [self showWithTitle:title error:error buttonTitle:buttonTitle completion:nil];
}

- (void)addButtonWithTitle:(NSString *)title block:(void (^)(void))block
{
    if (block) self.blocks[@(self.numberOfButtons)] = [block copy];
    [self addButtonWithTitle:title];
}

- (void)addCancelButtonWithTitle:(NSString *)title block:(void (^)(void))block
{
    NSInteger cancelIndex = self.numberOfButtons;
    [self addButtonWithTitle:title block:block];
    self.cancelButtonIndex = cancelIndex;
}

#pragma mark - UIAlertView

- (id <UIAlertViewDelegate>)delegate
{
    return self.actualDelegate;
}

- (void)setDelegate:(id <UIAlertViewDelegate>)delegate
{
    if (delegate == self) {
        [super setDelegate:self];
    } else {
        self.actualDelegate = delegate;
    }
}

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    _blocks = [NSMutableDictionary new];
    self.delegate = self;
    return self;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if ([self.actualDelegate respondsToSelector:_cmd]) {
        [self.actualDelegate alertView:alertView clickedButtonAtIndex:buttonIndex];
    }
}

- (BOOL)alertViewShouldEnableFirstOtherButton:(UIAlertView *)alertView
{
    if ([self.actualDelegate respondsToSelector:_cmd]) {
        return [self.actualDelegate alertViewShouldEnableFirstOtherButton:alertView];
    }
    return YES;
}

- (void)willPresentAlertView:(UIAlertView *)alertView
{
    if ([self.actualDelegate respondsToSelector:_cmd]) {
        [self.actualDelegate willPresentAlertView:alertView];
    }
}

- (void)didPresentAlertView:(UIAlertView *)alertView
{
    if ([self.actualDelegate respondsToSelector:_cmd]) {
        [self.actualDelegate didPresentAlertView:alertView];
    }
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if ([self.actualDelegate respondsToSelector:_cmd]) {
        [self.actualDelegate alertView:alertView willDismissWithButtonIndex:buttonIndex];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    void (^block)(void) = self.blocks[@(buttonIndex)];
    if (block) block();
    if ([self.actualDelegate respondsToSelector:_cmd]) {
        [self.actualDelegate alertView:alertView didDismissWithButtonIndex:buttonIndex];
    }
}

- (void)alertViewCancel:(UIAlertView *)alertView
{
    if ([self.actualDelegate respondsToSelector:_cmd]) {
        [self.actualDelegate alertViewCancel:alertView];
    }
}

@end
