//  UIAlertAction+WebViewSheets.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface UIAlertAction (WebViewSheets)

/**
 * Returns an array of the following actions: "Open"; "Open in [browser]"; "Send to [Read Later service]"; "Copy URL"; "Cancel".
 */
+ (NSArray *)actionsOpeningURL:(NSURL *)URL fromViewController:(UIViewController *)viewController;

@end
