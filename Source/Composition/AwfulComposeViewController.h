//
//  AwfulComposeViewController.h
//  Awful
//
//  Created by Nolan Waite on 2013-02-26.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulTextView.h"

@interface AwfulComposeViewController : UIViewController <AwfulTextViewDelegate, UITextViewDelegate>

@property (readonly, nonatomic) AwfulTextView *textView;

@end
