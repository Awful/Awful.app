//  SmilieDataStore.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieDataStore.h"
#import "Smilie.h"

@implementation SmilieDataStore

+ (NSManagedObjectModel *)managedObjectModel
{
    NSURL *modelURL = [[NSBundle bundleForClass:[Smilie class]] URLForResource:@"Smilies" withExtension:@"momd"];
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
}

+ (NSURL *)bundledSmilieStoreURL
{
    return [[NSBundle bundleForClass:[Smilie class]] URLForResource:@"Smilies" withExtension:@"sqlite"];
}

@end
