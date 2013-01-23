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


static int AwfulControlEventComposerFormat = UIControlEventApplicationReserved | (1<<0);
//static int AwfulControlEventComposerInsert = UIControlEventApplicationReserved | (1<<1);
static int AwfulControlEventComposerKey = UIControlEventApplicationReserved | (1<<2);

@interface AwfulComposerInputAccessoryView : UIControl {
    UIPopoverController *pop;
}

@property (readonly) AwfulPostFormatStyle formatState;
@property (readonly,nonatomic) UISegmentedControl* formattingControl;
@property (readonly,nonatomic) UISegmentedControl* insertionControl;
@property (readonly,nonatomic) UISegmentedControl* extraKeysControl;

@end
