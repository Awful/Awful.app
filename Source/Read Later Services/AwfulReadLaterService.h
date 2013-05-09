//
//  AwfulReadLaterService.h
//  Awful
//
//  Created by Nolan Waite on 2013-05-09.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <Foundation/Foundation.h>

// A "Read Later" Service is a third-party service that stores and formats website contents.
@interface AwfulReadLaterService : NSObject

// Returns an array of instances of AwfulReadLaterService, one for each known "Read Later" service
// that can save a URL.
+ (NSArray *)availableServices;

// Text appropriate for a button that sends a URL to the service.
@property (readonly, nonatomic) NSString *callToAction;

// Attempt to send a URL to the service.
//
// A progress HUD is displayed while saving, and an alert view will present any errors.
- (void)saveURL:(NSURL *)url;

@end
