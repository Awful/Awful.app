// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulForum.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulForumAttributes {
	__unsafe_unretained NSString *expanded;
	__unsafe_unretained NSString *favoriteIndex;
	__unsafe_unretained NSString *forumID;
	__unsafe_unretained NSString *index;
	__unsafe_unretained NSString *isFavorite;
	__unsafe_unretained NSString *name;
} AwfulForumAttributes;

extern const struct AwfulForumRelationships {
	__unsafe_unretained NSString *category;
	__unsafe_unretained NSString *children;
	__unsafe_unretained NSString *parentForum;
	__unsafe_unretained NSString *threads;
} AwfulForumRelationships;

extern const struct AwfulForumFetchedProperties {
} AwfulForumFetchedProperties;

@class AwfulCategory;
@class AwfulForum;
@class AwfulForum;
@class AwfulThread;








@interface AwfulForumID : NSManagedObjectID {}
@end

@interface _AwfulForum : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulForumID*)objectID;




@property (nonatomic, strong) NSNumber* expanded;


@property BOOL expandedValue;
- (BOOL)expandedValue;
- (void)setExpandedValue:(BOOL)value_;

//- (BOOL)validateExpanded:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* favoriteIndex;


@property int32_t favoriteIndexValue;
- (int32_t)favoriteIndexValue;
- (void)setFavoriteIndexValue:(int32_t)value_;

//- (BOOL)validateFavoriteIndex:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* forumID;


//- (BOOL)validateForumID:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* index;


@property int32_t indexValue;
- (int32_t)indexValue;
- (void)setIndexValue:(int32_t)value_;

//- (BOOL)validateIndex:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* isFavorite;


@property BOOL isFavoriteValue;
- (BOOL)isFavoriteValue;
- (void)setIsFavoriteValue:(BOOL)value_;

//- (BOOL)validateIsFavorite:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* name;


//- (BOOL)validateName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulCategory* category;

//- (BOOL)validateCategory:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSOrderedSet* children;

- (NSMutableOrderedSet*)childrenSet;




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


- (NSNumber*)primitiveExpanded;
- (void)setPrimitiveExpanded:(NSNumber*)value;

- (BOOL)primitiveExpandedValue;
- (void)setPrimitiveExpandedValue:(BOOL)value_;




- (NSNumber*)primitiveFavoriteIndex;
- (void)setPrimitiveFavoriteIndex:(NSNumber*)value;

- (int32_t)primitiveFavoriteIndexValue;
- (void)setPrimitiveFavoriteIndexValue:(int32_t)value_;




- (NSString*)primitiveForumID;
- (void)setPrimitiveForumID:(NSString*)value;




- (NSNumber*)primitiveIndex;
- (void)setPrimitiveIndex:(NSNumber*)value;

- (int32_t)primitiveIndexValue;
- (void)setPrimitiveIndexValue:(int32_t)value_;




- (NSNumber*)primitiveIsFavorite;
- (void)setPrimitiveIsFavorite:(NSNumber*)value;

- (BOOL)primitiveIsFavoriteValue;
- (void)setPrimitiveIsFavoriteValue:(BOOL)value_;




- (NSString*)primitiveName;
- (void)setPrimitiveName:(NSString*)value;





- (AwfulCategory*)primitiveCategory;
- (void)setPrimitiveCategory:(AwfulCategory*)value;



- (NSMutableOrderedSet*)primitiveChildren;
- (void)setPrimitiveChildren:(NSMutableOrderedSet*)value;



- (AwfulForum*)primitiveParentForum;
- (void)setPrimitiveParentForum:(AwfulForum*)value;



- (NSMutableSet*)primitiveThreads;
- (void)setPrimitiveThreads:(NSMutableSet*)value;


@end
