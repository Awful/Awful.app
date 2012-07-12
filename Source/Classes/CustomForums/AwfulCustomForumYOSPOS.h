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

//define the forum ID
static AwfulCustomForumID const AwfulCustomForumYOSPOS = (AwfulCustomForumID)219;

//declare our replacement classes
//just threadcell is necessary for basic color/font changes
@interface AwfulYOSPOSThreadCell : AwfulThreadCell
@end

//but you can customize the ThreadListController for more options
@interface AwfulYOSPOSThreadListController : AwfulThreadListController
@end

//and to go all out, replace other components, like here the Pull to Refresh Header
@interface AwfulYOSPOSRefreshControl : AwfulRefreshControl
@end

//and a replacement activity spinner
@interface AwfulYOSPOSActivityIndicatorView : UIActivityIndicatorView {
    UILabel *_lbl;
    NSTimer *_timer;
}
-(id) initWithInvertedColors;
@end


//helper categories
@interface UIColor (YOSPOS)
+(UIColor*) YOSPOSGreenColor;
+(UIColor*) YOSPOSAmberColor;
@end

@interface UIImage (YOSPOS)
-(UIImage*) grayscaleVersion;
-(UIImage*) greenVersion;
-(UIImage*) amberVersion;
+(UIImage *)blackNavigationBarImageForMetrics:(UIBarMetrics)metrics;
@end