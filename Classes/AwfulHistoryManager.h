//
//  AwfulHistoryManager.h
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHistory.h"


@interface AwfulHistoryManager : NSObject {
    NSMutableArray *_recordedHistory;
    NSMutableArray *_recordedForward;
}

@property (nonatomic, retain) NSMutableArray *recordedHistory;
@property (nonatomic, retain) NSMutableArray *recordedForward;

-(void)addHistory : (id<AwfulHistoryRecorder>)hist;
-(void)goBack;
-(void)goForward;
-(BOOL)isBackEnabled;
-(BOOL)isForwardEnabled;

@end
