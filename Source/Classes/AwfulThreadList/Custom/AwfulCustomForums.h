//
//  AwfulCustomForums.h
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef int AwfulCustomForumID;

@class AwfulForum;
@class AwfulThreadCell;
@class AwfulThread;
@class AwfulThreadListController;

@interface AwfulCustomForums : NSObject

+(NSString*) cellIdentifierForForum:(AwfulForum*)forum;
+(AwfulThreadCell*) cellForIdentifier:(NSString*)cellIdentifier;


+(AwfulThreadListController*) threadListControllerForForum:(AwfulForum*)forum;
@end
