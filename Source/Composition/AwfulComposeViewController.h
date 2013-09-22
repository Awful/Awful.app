//  AwfulComposeViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulTextView.h"

// Subclasses should call super if they implement -loadView.
@interface AwfulComposeViewController : AwfulViewController <AwfulTextViewDelegate, UITextViewDelegate>

@property (readonly, nonatomic) AwfulTextView *textView;

@end
