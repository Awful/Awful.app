//
//  AwfulURLActivity.m
//  Awful
//
//  Created by Chris Williams on 2/15/14.
//  Copyright (c) 2014 Awful Contributors. All rights reserved.
//

#import "AwfulURLActivity.h"

#import "AwfulExternalBrowser.h"
#import "AwfulReadLaterService.h"

@implementation AwfulURLActivity

+ (UIActivityViewController *)activityControllerForUrl:(NSURL *)url
{
	NSArray *exteralBrowserActivities = [AwfulExternalBrowser availableBrowserActivities];
	NSArray *readLaterActivities = [AwfulReadLaterService availableServices];
	
	UIActivityViewController *activityController = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:[readLaterActivities
																																		 arrayByAddingObjectsFromArray:exteralBrowserActivities]];
	return activityController;
}


- (void)prepareWithActivityItems:(NSArray *)activityItems
{
	for (id activityItem in activityItems) {
		if ([activityItem isKindOfClass:[NSURL class]]) {
			self.url = activityItem;
		}
	}
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
	for (id activityItem in activityItems) {
		if ([activityItem isKindOfClass:[NSURL class]] && [[UIApplication sharedApplication] canOpenURL:activityItem]) {
			return YES;
		}
	}
	
	return NO;
}


@end