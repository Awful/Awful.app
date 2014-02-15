//  AwfulReadLaterService.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

#import "AwfulExternalBrowser.h"

// A "Read Later" Service is a third-party service that stores and formats website contents.
@interface AwfulReadLaterService : AwfulURLActivity

// Returns an array of instances of AwfulReadLaterService, one for each known "Read Later" service
// that can save a URL.
+ (NSArray *)availableServices;

// Attempt to send a URL to the service.
//
// A progress HUD is displayed while saving, and an alert view will present any errors.
- (void)saveURL:(NSURL *)url;

@end
