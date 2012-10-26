//
//  AwfulPage.h
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulSplitViewController.h"

typedef enum {
    AwfulPageDestinationTypeFirst,
    AwfulPageDestinationTypeLast,
    AwfulPageDestinationTypeNewpost,
    AwfulPageDestinationTypeSpecific
} AwfulPageDestinationType;

@class AwfulActions;
@class AwfulPostActions;
@class AwfulThread;


@interface AwfulPage : UIViewController

+ (id)newDeviceSpecificPage;

@property (nonatomic, strong) AwfulThread *thread;

@property (nonatomic, strong) NSString *threadID;

@property (nonatomic, assign) AwfulPageDestinationType destinationType;

@property (nonatomic, strong) AwfulActions *actions;

@property (nonatomic, assign) NSInteger currentPage;

@property (nonatomic, assign) NSInteger numberOfPages;

- (IBAction)hardRefresh;

- (void)updatePagesLabel;

- (void)refresh;

- (void)loadPageNum:(NSUInteger)pageNum;

- (void)showCompletionMessage:(NSString *)message;

@end


extern NSString * const AwfulPageWillLoadNotification;

extern NSString * const AwfulPageDidLoadNotification;


@interface AwfulPageIpad : AwfulPage

@end
