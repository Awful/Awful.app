//  AwfulReadLaterService.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import SafariServices;

#import "AwfulReadLaterService.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulSettings.h"
#import "InstapaperAPIClient.h"
#import <MRProgress/MRProgressOverlayView.h>
#import <PocketAPI/PocketAPI.h>

@interface InstapaperReadLaterService : AwfulReadLaterService @end
@interface PocketReadLaterService : AwfulReadLaterService @end
@interface ReadingListReadLaterService : AwfulReadLaterService @end


@interface AwfulReadLaterService ()

// Returns YES if the service is likely able to save a URL.
//
// Saving will fail if this returns NO; it may fail even if it returns YES.
@property (readonly, getter=isReady, nonatomic) BOOL ready;

- (void)showProgressHUD;

@property (strong, nonatomic) MRProgressOverlayView *overlay;

// Text appropriate for a progress HUD while saving is in progress.
@property (readonly, nonatomic) NSString *ongoingStatusText;

// Dismiss the progress HUD. If there was an error, show it in an alert.
- (void)done:(NSError *)error;

// Text appropriate for a progress HUD after saving succeeds.
@property (readonly, nonatomic) NSString *successfulStatusText;

@end


@implementation AwfulReadLaterService

+ (NSArray *)availableServices
{
    return [@[
        [InstapaperReadLaterService new],
        [PocketReadLaterService new],
		[ReadingListReadLaterService new],
    ] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"ready = YES"]];
}

- (void)saveURL:(NSURL *)url
{
    [self doesNotRecognizeSelector:_cmd];
}

- (void)showProgressHUD
{
    self.overlay = [MRProgressOverlayView showOverlayAddedTo:[AwfulAppDelegate instance].window
                                                       title:self.ongoingStatusText
                                                        mode:MRProgressOverlayViewModeIndeterminate
                                                    animated:YES];
    self.overlay.tintColor = [AwfulTheme currentTheme][@"tintColor"];
}

- (void)done:(NSError *)error
{
    if (error) {
        [self.overlay dismiss:NO];
        [AwfulAlertView showWithTitle:@"Could Not Send Link" error:error buttonTitle:@"OK"];
    } else {
        self.overlay.titleLabelText = self.successfulStatusText;
        self.overlay.mode = MRProgressOverlayViewModeCheckmark;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.overlay dismiss:YES];
        });
    }
}

@end


@implementation InstapaperReadLaterService

- (BOOL)isReady
{
    return !![AwfulSettings settings].instapaperUsername;
}

- (NSString *)callToAction
{
    return @"Send to Instapaper";
}

- (NSString *)ongoingStatusText
{
    return @"Sending…";
}

- (NSString *)successfulStatusText
{
    return @"Sent";
}

- (void)saveURL:(NSURL *)url
{
    [self showProgressHUD];
    AwfulSettings *settings = [AwfulSettings settings];
    [[InstapaperAPIClient client] addURL:url
                             forUsername:settings.instapaperUsername
                                password:settings.instapaperPassword
                                 andThen:^(NSError *error)
    {
        [self done:error];
    }];
}

@end


@implementation PocketReadLaterService

- (BOOL)isReady
{
    return [[PocketAPI sharedAPI] isLoggedIn];
}

- (NSString *)callToAction
{
    return @"Save to Pocket";
}

- (NSString *)ongoingStatusText
{
    return @"Saving…";
}

- (NSString *)successfulStatusText
{
    return @"Saved";
}

- (void)saveURL:(NSURL *)url
{
    [self showProgressHUD];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [[PocketAPI sharedAPI] saveURL:url handler:^(PocketAPI *api, NSURL *url, NSError *error) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        [self done:error];
    }];
}

@end


@implementation ReadingListReadLaterService

- (BOOL)isReady
{
    return YES;
}

- (NSString *)callToAction
{
    return @"Add to Reading List";
}

- (NSString *)ongoingStatusText
{
    return @"Adding…";
}

- (NSString *)successfulStatusText
{
    return @"Added";
}

- (void)saveURL:(NSURL *)url
{
	[self showProgressHUD];
	
	NSError *error = nil;
	
	[[SSReadingList defaultReadingList] addReadingListItemWithURL:url
															title:nil
													  previewText:nil
															error:&error];
	
	
	[self done:error];
}

@end
