//  AwfulDateFormatters.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulDateFormatters.h"

@interface AwfulDateFormatters ()

@property (nonatomic) NSDateFormatter *postDateFormatter;
@property (nonatomic) NSDateFormatter *regDateFormatter;

@end


@implementation AwfulDateFormatters

+ (NSDateFormatter *)postDateFormatter
{
	static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
		
		// Jan 2, 2003 16:05
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
    });
    return formatter;
}

+ (NSDateFormatter *)regDateFormatter
{
	static NSDateFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [NSDateFormatter new];
		
		// Jan 2, 2003
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterNoStyle;
    });
    return formatter;
}

@end
