//
//  BookmarksController.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadList.h"

typedef enum {
    AwfulThreadCellTypeUnknown,
    AwfulThreadCellTypeThread,
    AwfulThreadCellTypePageNav
} AwfulThreadCellType;

@interface AwfulBookmarksController : AwfulThreadList <UIScrollViewDelegate>

-(AwfulThreadCellType)getTypeAtIndexPath : (NSIndexPath *)indexPath;

@end

@interface AwfulBookmarksControllerIpad : AwfulBookmarksController {
    
}

@end