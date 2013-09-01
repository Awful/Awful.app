//  AwfulReadLaterService.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulReadLaterService.h"
#import "AwfulAlertView.h"
#import "AwfulSettings.h"
#import "InstapaperAPIClient.h"
#import <PocketAPI/PocketAPI.h>
#import <SVProgressHUD/SVProgressHUD.h>

@interface InstapaperReadLaterService : AwfulReadLaterService @end
@interface PocketReadLaterService : AwfulReadLaterService @end


@interface AwfulReadLaterService ()

// Returns YES if the service is likely able to save a URL.
//
// Saving will fail if this returns NO; it may fail even if it returns YES.
@property (readonly, getter=isReady, nonatomic) BOOL ready;

- (void)showProgressHUD;

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
    ] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"ready = YES"]];
}

- (void)saveURL:(NSURL *)url
{
    [self doesNotRecognizeSelector:_cmd];
}

- (void)showProgressHUD
{
    [SVProgressHUD showWithStatus:self.ongoingStatusText];
}

- (void)done:(NSError *)error
{
    if (error) {
        [SVProgressHUD dismiss];
        [AwfulAlertView showWithTitle:@"Could Not Send Link" error:error buttonTitle:@"OK"];
    } else {
         [SVProgressHUD showSuccessWithStatus:self.successfulStatusText];
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
