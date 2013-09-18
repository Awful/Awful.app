//  AwfulThreadTag.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTag.h"

@implementation AwfulThreadTag

+ (NSString *)emptyThreadTagImageName
{
    return @"empty-thread-tag";
}
+ (NSString *)emptyPrivateMessageTagImageName
{
    return @"empty-pm-tag";
}

#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)coder
{
    if (!(self = [self init])) return nil;
    _imageName = [coder decodeObjectForKey:ImageNameKey];
    _composeID = [coder decodeObjectForKey:ComposeIDKey];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.imageName forKey:ImageNameKey];
    [coder encodeObject:self.composeID forKey:ComposeIDKey];
}

static NSString * const ImageNameKey = @"Image name";
static NSString * const ComposeIDKey = @"Compose ID";

@end
