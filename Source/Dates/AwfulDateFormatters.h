//  AwfulDateFormatters.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>

/**
 * AwfulDateFormatters collects date formatters that are common across multiple screens.
 */
@interface AwfulDateFormatters : NSObject

/**
 * Returns a date formatter that looks like "Jan 2, 2003 16:05".
 */
+ (NSDateFormatter *)postDateFormatter;

/**
 * Returns a date formatter that looks like "Jan 2, 2003".
 */
+ (NSDateFormatter *)regDateFormatter;

@end
