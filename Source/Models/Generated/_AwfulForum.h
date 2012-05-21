// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulForum.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulForumAttributes {
	__unsafe_unretained NSString *forumID;
	__unsafe_unretained NSString *index;
	__unsafe_unretained NSString *name;
} AwfulForumAttributes;

extern const struct AwfulForumRelationships {
	__unsafe_unretained NSString *children;
	__unsafe_unretained NSString *favorite;
	__unsafe_unretained NSString *parentForum;
	__unsafe_unretained NSString *threads;
} AwfulForumRelationships;

extern const struct AwfulForumFetchedProperties {
} AwfulForumFetchedProperties;

@class AwfulForum;
@class NSManagedObject;
@class AwfulForum;
@class AwfulThread;





@interface AwfulForumID : NSManagedObjectID {}
@end

@interface _AwfulForum : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulForumID*)objectID;




@property (nonatomic, strong) NSString* forumID;


//- (BOOL)validateForumID:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* index;


@property int32_t indexValue;
- (int32_t)indexValue;
- (void)setIndexValue:(int32_t)value_;

//- (BOOL)validateIndex:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* name;


//- (BOOL)validateName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSOrderedSet* children;

- (NSMutableOrderedSet*)childrenSet;




@property (nonatomic, strong) NSManagedObject* favorite;

//- (BOOL)validateFavorite:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulForum* parentForum;

//- (BOOL)validateParentForum:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSSet* threads;

- (NSMutableSet*)threadsSet;





@end

@interface _AwfulForum (CoreDataGeneratedAccessors)

- (void)addChildren:(NSOrderedSet*)value_;
- (void)removeChildren:(NSOrderedSet*)value_;
- (void)addChildrenObject:(AwfulForum*)value_;
- (void)removeChildrenObject:(AwfulForum*)value_;

- (void)addThreads:(NSSet*)value_;
- (void)removeThreads:(NSSet*)value_;
- (void)addThreadsObject:(AwfulThread*)value_;
- (void)removeThreadsObject:(AwfulThread*)value_;

@end

@interface _AwfulForum (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveForumID;
- (void)setPrimitiveForumID:(NSString*)value;




- (NSNumber*)primitiveIndex;
- (void)setPrimitiveIndex:(NSNumber*)value;

- (int32_t)primitiveIndexValue;
- (void)setPrimitiveIndexValue:(int32_t)value_;




- (NSString*)primitiveName;
- (void)setPrimitiveName:(NSString*)value;





- (NSMutableOrderedSet*)primitiveChildren;
- (void)setPrimitiveChildren:(NSMutableOrderedSet*)value;



- (NSManagedObject*)primitiveFavorite;
- (void)setPrimitiveFavorite:(NSManagedObject*)value;



- (AwfulForum*)primitiveParentForum;
- (void)setPrimitiveParentForum:(AwfulForum*)value;



- (NSMutableSet*)primitiveThreads;
- (void)setPrimitiveThreads:(NSMutableSet*)value;


@end
