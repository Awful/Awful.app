//  AwfulBan.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBan.h"

@implementation AwfulBan

- (BOOL)isEqual:(AwfulBan *)other
{
    return ([other isKindOfClass:[AwfulBan class]] &&
            self.punishment == other.punishment &&
            [self.date isEqualToDate:other.date] &&
            [self.user isEqual:other.user]);
}

- (NSUInteger)hash
{
    return self.date.hash ^ self.user.hash;
}

@end
