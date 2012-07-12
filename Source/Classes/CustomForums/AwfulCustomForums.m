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

#import "AwfulCustomForumYOSPOS.h"
#import "AwfulCustomForumFYAD.h"
#import "AwfulCustomForumFilmDump.h"


@implementation AwfulCustomForums

//If you have a custom thread cell, add it here
//Cell Identifier should be the same name as the thread class
+(NSString*) cellIdentifierForForum:(AwfulForum*)forum {
    NSString *threadCell;
    
    switch (forum.forumID.intValue) {
            
        case AwfulCustomForumYOSPOS:
            threadCell = @"AwfulYOSPOSThreadCell";
            break;
            
        case AwfulCustomForumFYAD:
            threadCell = @"AwfulFYADThreadCell";
            break;
          
        case AwfulCustomForumFilmDump:
            threadCell = @"AwfulFilmDumpThreadCell";
            break;
            
        //add any new cell as another case here
            
        default:
            threadCell = @"AwfulThreadCell";
    }
    
    return threadCell;
}

+(AwfulThreadCell*) cellForIdentifier:(NSString*)cellIdentifier {
    AwfulThreadCell* cell = [NSClassFromString(cellIdentifier) new];
    return cell;
}

//If you want to replace the entire threadlist controller, add that here
+(AwfulThreadListController*) threadListControllerForForum:(AwfulForum*)forum {
    NSString* className;
    switch (forum.forumID.intValue) {
        case AwfulCustomForumYOSPOS:
            className = @"AwfulYOSPOSThreadListController";
            break;
            

        default:
            className = @"AwfulThreadListController";
    }
    AwfulThreadListController *threadList = [NSClassFromString(className) new];
    [threadList awakeFromNib];
    return threadList;
}

@end
