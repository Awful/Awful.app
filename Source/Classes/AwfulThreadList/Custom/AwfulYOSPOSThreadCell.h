//
//  AwfulYOSPOSThreadCell.h
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCustomForums.h"
#import "AwfulThreadCell.h"

static AwfulCustomForumID const AwfulCustomForumYOSPOS = (AwfulCustomForumID)219;

@interface AwfulYOSPOSThreadCell : AwfulThreadCell

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