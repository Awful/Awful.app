//  NeedsFullAccessView.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
@class KeyboardViewController;

@interface NeedsFullAccessView : UIView

+ (instancetype)newFromNibWithOwner:(KeyboardViewController *)owner;

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (copy, nonatomic) void (^tapAction)(void);

@end
