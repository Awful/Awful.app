//  NeedsFullAccessView.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface NeedsFullAccessView : UIView

+ (instancetype)newFromNib;

@property (weak, nonatomic) IBOutlet UITextView *textView;

@end
