//  AwfulThreadTag.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulManagedObject.h"

/**
 * An AwfulThreadTag object describes threads and messages.
 */
@interface AwfulThreadTag : AwfulManagedObject

/**
 * Why messages and threads are tagged with this tag.
 */
@property (copy, nonatomic) NSString *explanation;

/**
 * The extensionless basename of the tag image's URL.
 */
@property (copy, nonatomic) NSString *imageName;

/**
 * An apparently unique ID for choosing tags when filtering threads or submitting forms.
 */
@property (copy, nonatomic) NSString *threadTagID;

/**
 * A set of AwfulForum objects whose threads may use the thread tag.
 */
@property (copy, nonatomic) NSSet *forums;

/**
 * A set of AwfulForum objects whose threads may use the thread tag as a secondary thread tag.
 */
@property (copy, nonatomic) NSSet *secondaryForums;

/**
 * A set of AwfulPrivateMessage objects with the thread tag.
 */
@property (copy, nonatomic) NSSet *messages;

/**
 * A set of AwfulThread objects with the thread tag as their secondary tag.
 */
@property (copy, nonatomic) NSSet *secondaryThreads;

/**
 * A set of AwfulThread objects with the thread tag as their primary tag.
 */
@property (copy, nonatomic) NSSet *threads;

/**
 * Returns an AwfulThreadTag object with the given ID and image name, updating an existing one or inserting a new one as necessary.
 */
+ (instancetype)firstOrNewThreadTagWithThreadTagID:(NSString *)threadTagID
                                         imageName:(NSString *)imageName
                            inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 * Returns an AwfulThreadTag object with the given ID and an image name derived from its URL, updating an existing one or inserting a new one as necessary.
 */
+ (instancetype)firstOrNewThreadTagWithThreadTagID:(NSString *)threadTagID
                                      threadTagURL:(NSURL *)threadTagURL
                            inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end
