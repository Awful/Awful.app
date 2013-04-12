//
//  AwfulComposeViewController.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>
#import "AwfulTextView.h"

// Subclasses should call super if they implement -loadView.
@interface AwfulComposeViewController : UIViewController <AwfulTextViewDelegate, UITextViewDelegate>

@property (readonly, nonatomic) AwfulTextView *textView;

@end
