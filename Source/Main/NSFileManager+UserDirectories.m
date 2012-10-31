//
//  NSFileManager+UserDirectories.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-31.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "NSFileManager+UserDirectories.h"

@implementation NSFileManager (UserDirectories)

- (NSURL *)cachesDirectory
{
    return [[self URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];
}

- (NSURL *)documentDirectory
{
    return [[self URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
