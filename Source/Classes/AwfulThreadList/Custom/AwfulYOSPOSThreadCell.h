//
//  AwfulYOSPOSThreadCell.h
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCustomForums.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadListController.h"
#import "AwfulRefreshControl.h"

static AwfulCustomForumID const AwfulCustomForumYOSPOS = (AwfulCustomForumID)219;

@interface AwfulYOSPOSThreadCell : AwfulThreadCell

@end

@interface AwfulYOSPOSThreadListController : AwfulThreadListController

@end

@interface AwfulYOSPOSRefreshControl : AwfulRefreshControl

@end

@interface AwfulYOSPOSActivityIndicatorView : UIActivityIndicatorView {
    UILabel *_lbl;
    NSTimer *_timer;
}

-(id) initWithInvertedColors;
@end

@interface UIColor (YOSPOS)
+(UIColor*) YOSPOSGreenColor;
+(UIColor*) YOSPOSAmberColor;
@end

@interface UIImage (YOSPOS)
-(UIImage*) grayscaleVersion;
-(UIImage*) greenVersion;
-(UIImage*) amberVersion;
@end