//  UIPasteboard+AwfulStringyURLs.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface UIPasteboard (AwfulStringyURLs)

/**
 * Returns a URL whether it was put on the pasteboard as a string or as a URL, or nil if neither occurred.
 */
- (NSURL *)awful_URL;

@end
