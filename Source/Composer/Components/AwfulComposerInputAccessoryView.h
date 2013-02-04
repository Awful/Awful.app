//
//  AwfulPostComposerInputAccessoryView.h
//  Awful
//
//  Created by me on 7/24/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulEmoticonChooserViewController.h"

typedef enum {
    AwfulPostFormatBold = 0,
    AwfulPostFormatItalic,
    AwfulPostFormatUnderline,
    AwfulPostFormatStrike,
    AwfulPostFormatSpoil
} AwfulPostFormatStyle;

@protocol AwfulComposerInputAccessoryViewDelegate <NSObject>

- (void)setFormat:(AwfulPostFormatStyle)format;
- (void)insertString:(NSString*)string;
- (void)insertImage:(int)imageType;
- (void)showEmoticonChooser;
@end

@interface AwfulComposerInputAccessoryView : UIControl {
    UIPopoverController *pop;
}

@property (readonly) AwfulPostFormatStyle formatState;
@property (readonly,nonatomic,strong) UISegmentedControl* formattingControl;
@property (readonly,nonatomic,strong) UISegmentedControl* insertionControl;
@property (readonly,nonatomic,strong) UISegmentedControl* extraKeysControl;
@property (nonatomic,strong) UIToolbar* toolbar;
@property (nonatomic) id<AwfulComposerInputAccessoryViewDelegate,AwfulEmoticonChooserDelegate> delegate;

@end
