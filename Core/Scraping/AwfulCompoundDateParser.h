//  AwfulCompoundDateParser.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

/// An AwfulCompoundDateParser extracts a date from a string by testing against several possible formats.
@interface AwfulCompoundDateParser : NSObject

/**
    Returns an initialized AwfulCompoundDateParser. This is the designated initializer.
 
    @param formats An array of NSString objects suitable for -[NSDateFormatter setDateFormat:]. Formatters use the "en_US_POSIX" locale.
 */
- (id)initWithFormats:(NSArray *)formats;

@property (readonly, copy, nonatomic) NSArray *formats;

/// Returns a date represented by a string.
- (NSDate *)dateFromString:(NSString *)string;

#pragma mark - Common parser factories

+ (instancetype)postDateParser;

@end
