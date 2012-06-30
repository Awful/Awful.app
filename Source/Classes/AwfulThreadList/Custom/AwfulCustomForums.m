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
            threadCell = @"AwfulYOSPOSThreadCell";
            break;
            
        case AwfulCustomForumFYAD:
            threadCell = @"AwfulFYADThreadCell";
            break;
          /*
        case AwfulCustomForumAskTell:
            threadCell = @"AwfulAskTellThreadCell";
            break;
           */
          
        case AwfulCustomForumFilmDump:
            threadCell = @"AwfulFilmDumpThreadCell";
            break;
            
        default:
            threadCell = @"AwfulThreadCell";
    }
    
    return threadCell;
}

+(AwfulThreadCell*) cellForIdentifier:(NSString*)cellIdentifier {
    AwfulThreadCell* cell = [NSClassFromString(cellIdentifier) new];
    return cell;
}

/*
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
*/
@end
