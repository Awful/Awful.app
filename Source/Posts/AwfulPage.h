//
//  AwfulPage.h
//  Awful
//
//  Created by Sean Berry on 7/29/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AwfulThread;


@interface AwfulPage : UIViewController

+ (id)newDeviceSpecificPage;

@property (nonatomic, strong) AwfulThread *thread;

@property (nonatomic, assign) NSInteger currentPage;

- (void)loadPage:(NSInteger)page;

@end


extern NSString * const AwfulPageDidLoadNotification;


@interface AwfulPageIpad : AwfulPage

@end
