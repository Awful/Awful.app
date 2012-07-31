//
//  AwfulPostComposerInputAccessoryView.h
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
    AwfulPostFormatBold = 0,
    AwfulPostFormatItalic,
    AwfulPostFormatUnderline,
    AwfulPostFormatStrike
} AwfulPostFormatStyle;


static int AwfulControlEventPostComposerFormat = UIControlEventApplicationReserved | (1<<0);
static int AwfulControlEventPostComposerInsert = UIControlEventApplicationReserved | (1<<1);

@interface AwfulPostComposerInputAccessoryView : UIControl {
    UIPopoverController *pop;
}

@property (readonly) AwfulPostFormatStyle formatState;
@property (readonly,strong) UISegmentedControl* formattingControl;
@property (readonly,strong) UISegmentedControl* insertionControl;

@end
