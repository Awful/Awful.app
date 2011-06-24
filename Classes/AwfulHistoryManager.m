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
    _recordedHistory = [[NSMutableArray alloc] init];
    _recordedForward = [[NSMutableArray alloc] init];
    
    return self;
}

-(void)dealloc
{
    [_recordedHistory release];
    [_recordedForward release];
    [super dealloc];
}

-(void)addHistory : (id<AwfulHistoryRecorder>)hist
{
    AwfulHistory *record = [hist newRecordedHistory];
    [self.recordedHistory addObject:record];
    [record release];

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
    
    AwfulHistory *record = [[self.recordedHistory lastObject] retain];
    [self.recordedHistory removeLastObject];
    
    id<AwfulHistoryRecorder> content = [record newThreadObj];
    [record release];
    loadContentVC((id<AwfulNavigatorContent>)content);
    [content release];
    
    self.recordedForward = old_forward;
}

-(void)goForward
{
    if(![self isForwardEnabled]) {
        return;
    }
    
    AwfulHistory *record = [[self.recordedForward lastObject] retain];
    [self.recordedForward removeLastObject];
    
    NSMutableArray *old_forward = [NSMutableArray arrayWithArray:self.recordedForward];
    
    id<AwfulHistoryRecorder> content = [record newThreadObj];
    [record release];
    loadContentVC((id<AwfulNavigatorContent>)content);
    [content release];
    
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
