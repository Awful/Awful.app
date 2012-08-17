//
//  AwfulPostCell.h
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulDraft.h"

static NSString* const AwfulPostCellIdentifierKey = @"AwfulPostCellIdentifierKey";
static NSString* const AwfulPostCellTextKey = @"AwfulPostCellTextKey";
static NSString* const AwfulPostCellDetailKey = @"AwfulPostCellDetailKey";
static NSString* const AwfulPostCellDraftInputKey = @"AwfulPostCellDraftInputKey";

@interface AwfulPostCell : UITableViewCell
-(void) didSelectCell:(UIViewController*)viewController;
@property (nonatomic,strong) NSDictionary* dictionary;
@property (nonatomic,strong) AwfulDraft* draft;
@end
