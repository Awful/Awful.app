//
//  AwfulHistoryManager.m
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHistoryManager.h"
#import "AwfulNavigator.h"

@implementation AwfulHistoryManager

@synthesize recordedHistory = _recordedHistory;
@synthesize recordedForward = _recordedForward;

-(id)init
{
    if((self=[super init])) {
        _recordedHistory = [[NSMutableArray alloc] init];
        _recordedForward = [[NSMutableArray alloc] init];
    }
    
    return self;
}

-(void)addHistory : (id<AwfulHistoryRecorder>)hist
{
    AwfulHistory *record = [hist newRecordedHistory];
    [self.recordedHistory addObject:record];

    if([self.recordedHistory count] > 20) {
        [self.recordedHistory removeObjectAtIndex:0];
    }

    [self.recordedForward removeAllObjects];
}

-(void)goBack
{
    if(![self isBackEnabled]) {
        return;
    }
    [self.recordedForward addObject:[self.recordedHistory lastObject]];
    NSMutableArray *old_forward = [NSMutableArray arrayWithArray:self.recordedForward];
    
    [self.recordedHistory removeLastObject];
    
    AwfulHistory *record = [self.recordedHistory lastObject];
    [self.recordedHistory removeLastObject];
    
    id<AwfulHistoryRecorder> content = [record newThreadObj];
    loadContentVC((id<AwfulNavigatorContent>)content);
    
    self.recordedForward = old_forward;
}

-(void)goForward
{
    if(![self isForwardEnabled]) {
        return;
    }
    
    AwfulHistory *record = [self.recordedForward lastObject];
    [self.recordedForward removeLastObject];
    
    NSMutableArray *old_forward = [NSMutableArray arrayWithArray:self.recordedForward];
    
    id<AwfulHistoryRecorder> content = [record newThreadObj];
    loadContentVC((id<AwfulNavigatorContent>)content);
    
    self.recordedForward = old_forward;
}

-(BOOL)isBackEnabled
{
    return [self.recordedHistory count] > 1;
}

-(BOOL)isForwardEnabled
{
    return [self.recordedForward count] > 0;
}

@end
