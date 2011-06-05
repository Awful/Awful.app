//
//  BookmarksController.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulThreadList.h"

@interface BookmarksController : AwfulThreadList <UIScrollViewDelegate> {
    NSTimer *refreshTimer;
    BOOL refreshed;
}

-(void)startTimer;
-(void)endTimer;

@end
