//
//  AwfulForum.h
//  Awful
//
//  Created by Sean Berry on 4/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class AwfulForum, AwfulThread;

@interface AwfulForum : NSManagedObject

@property (nonatomic, retain) NSString * forumID;
@property (nonatomic, retain) NSNumber * index;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSNumber * favorited;
@property (nonatomic, retain) NSOrderedSet *children;
@property (nonatomic, retain) AwfulForum *parentForum;
@property (nonatomic, retain) NSSet *threads;
@end

@interface AwfulForum (CoreDataGeneratedAccessors)

- (void)insertObject:(AwfulForum *)value inChildrenAtIndex:(NSUInteger)idx;
- (void)removeObjectFromChildrenAtIndex:(NSUInteger)idx;
- (void)insertChildren:(NSArray *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeChildrenAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInChildrenAtIndex:(NSUInteger)idx withObject:(AwfulForum *)value;
- (void)replaceChildrenAtIndexes:(NSIndexSet *)indexes withChildren:(NSArray *)values;
- (void)addChildrenObject:(AwfulForum *)value;
- (void)removeChildrenObject:(AwfulForum *)value;
- (void)addChildren:(NSOrderedSet *)values;
- (void)removeChildren:(NSOrderedSet *)values;
- (void)addThreadsObject:(AwfulThread *)value;
- (void)removeThreadsObject:(AwfulThread *)value;
- (void)addThreads:(NSSet *)values;
- (void)removeThreads:(NSSet *)values;

@end
