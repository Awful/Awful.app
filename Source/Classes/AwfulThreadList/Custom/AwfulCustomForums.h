//
//  AwfulCustomForums.h
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef enum {
    AwfulCustomForumFYAD = 26,
    AwfulCustomForumFilmDump = 133,
    AwfulCustomForumAskTell = 158,
    AwfulCustomForumYOSPOS = 219
} AwfulCustomForum;

@class AwfulForum;
@class AwfulThreadCell;
@class AwfulThread;

@interface AwfulCustomForums : NSObject

+(NSString*) cellIdentifierForForum:(AwfulForum*)forum;
+(AwfulThreadCell*) cellForThread:(AwfulThread*)thread;
@end
