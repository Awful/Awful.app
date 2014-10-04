//  SmilieDataStore.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreData;

@interface SmilieDataStore : NSObject

+ (NSManagedObjectModel *)managedObjectModel;

+ (NSURL *)bundledSmilieStoreURL;

@end
