//
//  BookmarksController.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulThreadList.h"

@interface AwfulBookmarksController : AwfulThreadList <UIScrollViewDelegate> {
    NSTimer *_refreshTimer;
    BOOL _refreshed;
}

@property (nonatomic, retain) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL refreshed;

-(void)startTimer;
-(void)endTimer;

-(void)swapToRefreshButton;
-(void)swapToStopButton;

@end

@interface AwfulBookmarksControllerIpad : AwfulBookmarksController {
    
}

@end