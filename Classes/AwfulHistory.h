//
//  AwfulHistory.h
//  Awful
//
//  Created by Regular Berry on 3/30/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

enum {
    AWFUL_HISTORY_UNKNOWN,
    AWFUL_HISTORY_PAGE,
    AWFUL_HISTORY_THREADLIST
};

@protocol AwfulHistoryRecorder;

@interface AwfulHistory : NSObject {
    int _historyType;
    int _pageNum;
    id _modelObj;
}

@property (nonatomic, assign) int historyType;
@property (nonatomic, assign) int pageNum;
@property (nonatomic, retain) id modelObj;

-(id)newThreadObj;

@end

@protocol AwfulHistoryRecorder <NSObject>

-(id)newRecordedHistory;
-(id)initWithAwfulHistory : (AwfulHistory *)history;
-(void)setRecorder : (AwfulHistory *)history;
                             
@end