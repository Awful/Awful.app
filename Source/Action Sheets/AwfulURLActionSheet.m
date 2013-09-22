//
//  AwfulURLActionSheet.m
//  Awful
//
//  Created by simon.frost on 22/09/2013.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulURLActionSheet.h"
#import "AwfulExternalBrowser.h"
#import "AwfulSettings.h"
#import "NSURL+Awful.h"
#import "AwfulAppDelegate.h"
#import "AwfulReadLaterService.h"
#import "AwfulBrowserViewController.h"

@implementation AwfulURLActionSheet

- (void) addSafariButton
{
    AwfulURLActionSheet * __weak weakSelf = self;
    [self addButtonWithTitle:@"Open in Safari" block:^{
        [[UIApplication sharedApplication] openURL:weakSelf.url];
    }];
}

- (void) addExternalBrowserButtons
{
    AwfulURLActionSheet * __weak weakSelf = self;
    for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
        if (![browser canOpenURL:weakSelf.url]) continue;
        [self addButtonWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title]
                           block:^{ [browser openURL:weakSelf.url]; }];
    }
}

- (void) addReadLaterButtons
{
    AwfulURLActionSheet * __weak weakSelf = self;
    for (AwfulReadLaterService *service in [AwfulReadLaterService availableServices]) {
        [self addButtonWithTitle:service.callToAction block:^{
            [service saveURL:weakSelf.url];
        }];
    }
}

- (void) addCopyURLButton
{
    AwfulURLActionSheet * __weak weakSelf = self;
    [self addButtonWithTitle:@"Copy URL" block:^{
        [AwfulSettings settings].lastOfferedPasteboardURL = [weakSelf.url absoluteString];
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: weakSelf.url,
            (id)kUTTypePlainText: [weakSelf.url absoluteString]
        } ];
    }];
}

@end
