//  AwfulCompoundDateParser.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulCompoundDateParser.h"

@implementation AwfulCompoundDateParser
{
    NSMutableArray *_formatters;
}

- (id)initWithFormats:(NSArray *)formats
{
    self = [super init];
    if (!self) return nil;
    _formatters = [NSMutableArray new];
    for (NSString *format in formats) {
        NSDateFormatter *formatter = [NSDateFormatter new];
        formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        formatter.timeZone = [NSTimeZone localTimeZone];
        formatter.dateFormat = format;
        [_formatters addObject:formatter];
    }
    return self;
}

- (NSArray *)formats
{
    return [_formatters valueForKey:@"dateFormat"];
}

- (NSDate *)dateFromString:(NSString *)string
{
	string = [string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    for (NSDateFormatter *formatter in _formatters) {
        NSDate *parsedDate = [formatter dateFromString:string];
        if (parsedDate) return parsedDate;
    }
    return nil;
}

+ (instancetype)postDateParser
{
    static AwfulCompoundDateParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[AwfulCompoundDateParser alloc] initWithFormats:@[ @"MMM d, yyyy h:mm a",
                                                                     @"MMM d, yyyy HH:mm" ]];
    });
    return parser;
}

@end
