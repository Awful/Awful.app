//
//  BookmarksController.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadListController.h"

@interface AwfulBookmarksController : AwfulThreadListController <UIScrollViewDelegate>

/* 
 Used for checking if there is a second page of bookmarks. Multiples of 40 means yeah sure.
 I can't just use [awfulThreads count] because I also want to allow users to remove bookmarks and have them disappear from the table immediately.
 */
@property NSUInteger threadCount; 

@end

@interface AwfulBookmarksControllerIpad : AwfulBookmarksController {
    
}

@end