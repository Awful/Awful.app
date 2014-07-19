//  AwfulActionSheet+WebViewSheets.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulActionSheet+WebViewSheets.h"
#import "AwfulAppDelegate.h"
#import "AwfulBrowserViewController.h"
#import "AwfulExternalBrowser.h"
#import "AwfulReadLaterService.h"
#import "AwfulSettings.h"

@implementation AwfulActionSheet (WebViewSheets)

+ (instancetype)actionSheetOpeningURL:(NSURL *)URL fromViewController:(UIViewController *)viewController addingActions:(void (^)(AwfulActionSheet *sheet))extraActionsBlock
{
    AwfulActionSheet *sheet = [self new];
    
    if ([URL opensInBrowser]) {
        sheet.title = URL.absoluteString;
        
        [sheet addButtonWithTitle:@"Open" block:^{
            NSURL *awfulURL = URL.awfulURL;
            if (awfulURL) {
                [[AwfulAppDelegate instance] openAwfulURL:awfulURL];
            } else {
                [AwfulBrowserViewController presentBrowserForURL:URL fromViewController:viewController];
            }
        }];
        
        [sheet addButtonWithTitle:@"Open in Safari" block:^{
            [[UIApplication sharedApplication] openURL:URL];
        }];
        
        for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
            if (![browser canOpenURL:URL]) continue;
            [sheet addButtonWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title] block:^{
                [browser openURL:URL];
            }];
        }
        
        for (AwfulReadLaterService *service in [AwfulReadLaterService availableServices]) {
            [sheet addButtonWithTitle:service.callToAction block:^{
                [service saveURL:URL];
            }];
        }
        
        [sheet addButtonWithTitle:@"Copy URL" block:^{
            [AwfulSettings settings].lastOfferedPasteboardURL = URL.absoluteString;
            [UIPasteboard generalPasteboard].awful_URL = URL;
        }];
    } else {
        [sheet addButtonWithTitle:@"Open" block:^{
            [[UIApplication sharedApplication] openURL:URL];
        }];
    }
    
    if (extraActionsBlock) extraActionsBlock(sheet);
    
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        [sheet addCancelButtonWithTitle:@"Cancel"];
    }

    return sheet;
}

@end
