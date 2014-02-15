//
//  AwfulURLActivities.h
//  Awful
//
//  Created by Chris Williams on 2/15/14.
//  Copyright (c) 2014 Awful Contributors. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulURLActivity : UIActivity

+ (UIActivityViewController *)activityControllerForUrl:(NSURL *)url;

@property (nonatomic, strong) NSURL *url;

@end
