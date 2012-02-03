//
//  AwfulHistoryManager.h
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulHistory.h"


@interface AwfulHistoryManager : NSObject

@property (nonatomic, strong) NSMutableArray *recordedHistory;
@property (nonatomic, strong) NSMutableArray *recordedForward;

-(void)addHistory : (id<AwfulHistoryRecorder>)hist;
-(void)goBack;
-(void)goForward;
-(BOOL)isBackEnabled;
-(BOOL)isForwardEnabled;

@end
