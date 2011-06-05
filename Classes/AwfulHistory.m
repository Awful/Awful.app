//
//  AwfulHistory.m
//  Awful
//
//  Created by Regular Berry on 3/30/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHistory.h"
#import "AwfulThreadList.h"
#import "AwfulPage.h"

@implementation AwfulHistory

@synthesize historyType = _historyType;
@synthesize pageNum = _pageNum;
@synthesize modelObj = _modelObj;

-(id)init
{
    _historyType = AWFUL_HISTORY_UNKNOWN;
    _pageNum = -1;
    _modelObj = nil;
    return self;
}

-(void)dealloc
{
    [_modelObj release];
    _modelObj = nil;
    [super dealloc];
}

-(id)newThreadObj
{
    if(self.historyType == AWFUL_HISTORY_UNKNOWN) {
        return nil;
    }
    
    id<AwfulHistoryRecorder> winner = nil;
    
    if(self.historyType == AWFUL_HISTORY_PAGE) {
        winner = [[AwfulPage alloc] initWithAwfulHistory:self];
    } else if(self.historyType == AWFUL_HISTORY_THREADLIST) {
        winner = [[AwfulThreadList alloc] initWithAwfulHistory:self];
    }
    
    return winner;
}

@end
