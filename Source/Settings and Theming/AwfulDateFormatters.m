//
//  AwfulDateFormatters.m
//  Awful
//
//  Created by Nolan Waite on 2013-02-25.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulDateFormatters.h"

@interface AwfulDateFormatters ()

@property (nonatomic) NSDateFormatter *postDateFormatter;
@property (nonatomic) NSDateFormatter *regDateFormatter;

@end


@implementation AwfulDateFormatters

+ (instancetype)formatters
{
    static AwfulDateFormatters *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (NSDateFormatter *)postDateFormatter
{
    if (_postDateFormatter) return _postDateFormatter;
    _postDateFormatter = [NSDateFormatter new];
    // Jan 2, 2003 16:05
    _postDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    _postDateFormatter.dateFormat = @"MMM d, yyyy HH:mm";
    return _postDateFormatter;
}

- (NSDateFormatter *)regDateFormatter
{
    if (_regDateFormatter) return _regDateFormatter;
    _regDateFormatter = [NSDateFormatter new];
    // Jan 2, 2003
    _regDateFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    _regDateFormatter.dateFormat = @"MMM d, yyyy";
    return _regDateFormatter;
}

@end
