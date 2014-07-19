//  AwfulActionSheet+WebViewSheets.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulActionSheet.h"

@interface AwfulActionSheet (WebViewSheets)

/**
 * Returns an action sheet with the following actions: "Open"; "Open in [browser]"; "Send to [Read Later service]"; "Copy URL"; "Cancel".
 */
+ (instancetype)actionSheetOpeningURL:(NSURL *)URL fromViewController:(UIViewController *)viewController addingActions:(void (^)(AwfulActionSheet *sheet))extraActionsBlock;

@end
