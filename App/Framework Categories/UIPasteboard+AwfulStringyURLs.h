//  UIPasteboard+AwfulStringyURLs.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@interface UIPasteboard (AwfulStringyURLs)

/**
 * The URL object of the first pasteboard item, whether it's an NSURL or an NSString. Setting this property replaces all current items in the pasteboard with a new item that contains both an NSURL and an NSString representation of the URL.
 */
@property (strong, nonatomic, setter=awful_setURL:) NSURL *awful_URL;

@end
