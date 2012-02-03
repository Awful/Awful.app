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
    if((self=[super init])) {
        _historyType = AwfulHistoryTypeUnknown;
        _pageNum = -1;
        _modelObj = nil;
    }
    return self;
}

-(id)newThreadObj
{
    if(self.historyType == AwfulHistoryTypeUnknown) {
        return nil;
    }
    
    id<AwfulHistoryRecorder> winner = nil;
    
    if(self.historyType == AwfulHistoryTypePage) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            winner = [[AwfulPageIpad alloc] initWithAwfulHistory:self];
        else
            winner = [[AwfulPage alloc] initWithAwfulHistory:self];
    } else if(self.historyType == AwfulHistoryTypeThreadlist) {
        winner = [[AwfulThreadList alloc] initWithAwfulHistory:self];
    }
    
    return winner;
}

@end
