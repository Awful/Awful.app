//  NSFileManager+UserDirectories.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NSFileManager+UserDirectories.h"

@implementation NSFileManager (UserDirectories)

- (NSURL *)applicationSupportDirectory
{
    NSURL *appSupport = [self URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].lastObject;
    NSString *bundleID = [NSBundle mainBundle].bundleIdentifier;
    return [appSupport URLByAppendingPathComponent:bundleID isDirectory:YES];
}

- (NSURL *)cachesDirectory
{
    return [[self URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSURL *)documentDirectory
{
    return [[self URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
