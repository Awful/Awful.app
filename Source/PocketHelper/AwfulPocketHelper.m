//
//  AwfulPocketHelper.m
//  Awful
//
//  Created by Simon Frost on 03/05/2013.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulPocketHelper.h"
#import "PocketAPI.h"
#import "AwfulAlertView.h"
#import "SVProgressHUD.h"

@implementation AwfulPocketHelper

+ (BOOL) isLoggedIn
{
    return [[PocketAPI sharedAPI] isLoggedIn];
}

+ (void) attemptToSaveURL:(NSURL *)url
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [[PocketAPI sharedAPI] saveURL:url handler: ^(PocketAPI *API, NSURL *URL,
                                                  NSError *error){
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        if(error){
            [AwfulAlertView showWithTitle:@"Could Not Save"
                                    error:error
                              buttonTitle:@"Alright"];
        } else {
            [SVProgressHUD showSuccessWithStatus:@"Saved"];
        }
    }];
}

@end
