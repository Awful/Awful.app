//
//  AwfulPersistOperation.h
//  Awful
//
//  Created by Nolan Waite on 12-05-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulPersistOperation : NSOperation

// Designated initializer.
// NOTE The managed object context cannot have a concurrency type of confinement.
- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@property (readonly, strong) NSError *error;

// Object IDs for any forums updated or created.
@property (readonly, strong) NSArray *forumObjectIDs;

@end
