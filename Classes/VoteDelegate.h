//
//  VoteDelegate.h
//  Awful
//
//  Created by Sean Berry on 11/28/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulThread.h"

@interface VoteDelegate : NSObject <UIActionSheetDelegate> {
    AwfulThread *thread;
}

@property (nonatomic, retain) AwfulThread *thread;

@end