//
//  AwfulCustomForums.m
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCustomForums.h"
#import "AwfulForum.h"


@implementation AwfulCustomForums

+(NSString*) cellIdentifierForForum:(AwfulForum*)forum {
    NSString *threadCell;
    
    switch (forum.forumID.intValue) {
            
        case AwfulCustomForumYOSPOS:
            threadCell = @"YOSPOSThreadCell";
            break;
            
        case AwfulCustomForumFYAD:
            threadCell = @"FYADThreadCell";
            break;
            
        case AwfulCustomForumAskTell:
            threadCell = @"AskTellThreadCell";
            break;
            
        case AwfulCustomForumFilmDump:
            threadCell = @"FilmDumpThreadCell";
            break;
            
        default:
            threadCell = @"ThreadCell";
    }
    
    return threadCell;
}

@end
