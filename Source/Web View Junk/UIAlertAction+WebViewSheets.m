//  UIAlertAction+WebViewSheets.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIAlertAction+WebViewSheets.h"
#import "AwfulAppDelegate.h"
#import "BrowserViewController.h"
#import "AwfulExternalBrowser.h"
#import "AwfulReadLaterService.h"
#import "AwfulSettings.h"

@implementation UIAlertAction (WebViewSheets)

+ (NSArray *)actionsOpeningURL:(NSURL *)URL fromViewController:(UIViewController *)viewController
{
    NSMutableArray *actions = [NSMutableArray new];
    if ([URL opensInBrowser]) {
        [actions addObject:[UIAlertAction actionWithTitle:@"Open" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSURL *awfulURL = URL.awfulURL;
            if (awfulURL) {
                [[AwfulAppDelegate instance] openAwfulURL:awfulURL];
            } else {
                [BrowserViewController presentBrowserForURL:URL fromViewController:viewController];
            }
        }]];
        
        [actions addObject:[UIAlertAction actionWithTitle:@"Open in Safari" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:URL];
        }]];
        
        for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
            if (![browser canOpenURL:URL]) continue;
            [actions addObject:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [browser openURL:URL];
            }]];
        }
        
        for (AwfulReadLaterService *service in [AwfulReadLaterService availableServices]) {
            [actions addObject:[UIAlertAction actionWithTitle:service.callToAction style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [service saveURL:URL];
            }]];
        }
        
        [actions addObject:[UIAlertAction actionWithTitle:@"Copy URL" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [AwfulSettings sharedSettings].lastOfferedPasteboardURL = URL.absoluteString;
            [UIPasteboard generalPasteboard].awful_URL = URL;
        }]];
    } else {
        [actions addObject:[UIAlertAction actionWithTitle:@"Open" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [[UIApplication sharedApplication] openURL:URL];
        }]];
    }
    return actions;
}

@end
