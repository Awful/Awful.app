//
//  AwfulCustomForums.m
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCustomForums.h"
#import "AwfulForum.h"
#import "AwfulThreadCell.h"
#import "AwfulThread+AwfulMethods.h"

#import "AwfulYOSPOSThreadCell.h"
#import "AwfulFYADThreadCell.h"
#import "AwfulAskTellThreadCell.h"
#import "AwfulFilmDumpThreadCell.h"


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

+(AwfulThreadCell*) cellForThread:(AwfulThread*)thread {
    AwfulThreadCell *cell;
    switch (thread.forum.forumID.intValue) {
            
        case AwfulCustomForumYOSPOS:
            cell = [AwfulYOSPOSThreadCell new];
            break;
            
        case AwfulCustomForumFYAD:
            cell = [AwfulFYADThreadCell new];
            break;
            
        case AwfulCustomForumAskTell:
            cell = [AwfulAskTellThreadCell new];
            break;
            
        case AwfulCustomForumFilmDump:
            cell = [AwfulFilmDumpThreadCell new];
            break;
            
        default:
            cell = [AwfulThreadCell new];
    }
    return cell;
    
}

@end
