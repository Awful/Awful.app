//  CloseBBcodeTagCommand.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

/// Auto-closes the nearest open BBcode tag in a text view.
@interface CloseBBcodeTagCommand : NSObject

- (instancetype)initWithTextView:(UITextView *)textView NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) UITextView *textView;

/// Whether the command can execute. KVO-compliant.
@property (readonly, assign, nonatomic) BOOL enabled;

/// Closes the nearest open BBcode tag.
- (void)execute;

@end
