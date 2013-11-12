//  AwfulThreadTag.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTag.h"

@implementation AwfulThreadTag

@dynamic explanation;
@dynamic imageName;
@dynamic threadTagID;
@dynamic messages;
@dynamic secondaryThreads;
@dynamic threads;

+ (instancetype)firstOrNewThreadTagWithThreadTagID:(NSString *)threadTagID
                                         imageName:(NSString *)imageName
                            inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSParameterAssert(threadTagID.length > 0 || imageName.length > 0);
    AwfulThreadTag *threadTag;
    if (threadTagID.length > 0) {
        threadTag = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                       matchingPredicateFormat:@"threadTagID = %@", threadTagID];
    } else if (imageName.length > 0) {
        threadTag = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                       matchingPredicateFormat:@"imageName = %@", imageName];
    } else {
        return nil;
    }
    if (!threadTag) {
        threadTag = [AwfulThreadTag insertInManagedObjectContext:managedObjectContext];
    }
    if (threadTagID.length > 0) {
        threadTag.threadTagID = threadTagID;
    }
    if (imageName.length > 0) {
        threadTag.imageName = imageName;
    }
    return threadTag;
}

+ (instancetype)firstOrNewThreadTagWithThreadTagID:(NSString *)threadTagID
                                      threadTagURL:(NSURL *)threadTagURL
                            inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSString *imageName = threadTagURL.lastPathComponent.stringByDeletingPathExtension;
    return [self firstOrNewThreadTagWithThreadTagID:threadTagID
                                          imageName:imageName
                             inManagedObjectContext:managedObjectContext];
}

@end
