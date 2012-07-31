// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulForum.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulForumAttributes {
	__unsafe_unretained NSString *desc;
	__unsafe_unretained NSString *expanded;
	__unsafe_unretained NSString *forumID;
	__unsafe_unretained NSString *index;
	__unsafe_unretained NSString *isCategory;
	__unsafe_unretained NSString *name;
} AwfulForumAttributes;

extern const struct AwfulForumRelationships {
	__unsafe_unretained NSString *category;
	__unsafe_unretained NSString *children;
	__unsafe_unretained NSString *favorite;
	__unsafe_unretained NSString *parentForum;
	__unsafe_unretained NSString *threadTags;
	__unsafe_unretained NSString *threads;
} AwfulForumRelationships;

extern const struct AwfulForumFetchedProperties {
} AwfulForumFetchedProperties;

@class AwfulForum;
@class AwfulForum;
@class AwfulFavorite;
@class AwfulForum;
@class AwfulThreadTag;
@class AwfulThread;








@interface AwfulForumID : NSManagedObjectID {}
@end

@interface _AwfulForum : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulForumID*)objectID;




@property (nonatomic, strong) NSString* desc;


//- (BOOL)validateDesc:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* expanded;


@property BOOL expandedValue;
- (BOOL)expandedValue;
- (void)setExpandedValue:(BOOL)value_;

//- (BOOL)validateExpanded:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* forumID;


//- (BOOL)validateForumID:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* index;


@property int32_t indexValue;
- (int32_t)indexValue;
- (void)setIndexValue:(int32_t)value_;

//- (BOOL)validateIndex:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* isCategory;


@property BOOL isCategoryValue;
- (BOOL)isCategoryValue;
- (void)setIsCategoryValue:(BOOL)value_;

//- (BOOL)validateIsCategory:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* name;


//- (BOOL)validateName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulForum* category;

//- (BOOL)validateCategory:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSOrderedSet* children;

- (NSMutableOrderedSet*)childrenSet;




@property (nonatomic, strong) AwfulFavorite* favorite;

//- (BOOL)validateFavorite:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulForum* parentForum;

//- (BOOL)validateParentForum:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSSet* threadTags;

- (NSMutableSet*)threadTagsSet;




@property (nonatomic, strong) NSSet* threads;

- (NSMutableSet*)threadsSet;





@end

@interface _AwfulForum (CoreDataGeneratedAccessors)

- (void)addChildren:(NSOrderedSet*)value_;
- (void)removeChildren:(NSOrderedSet*)value_;
- (void)addChildrenObject:(AwfulForum*)value_;
- (void)removeChildrenObject:(AwfulForum*)value_;

- (void)addThreadTags:(NSSet*)value_;
- (void)removeThreadTags:(NSSet*)value_;
- (void)addThreadTagsObject:(AwfulThreadTag*)value_;
- (void)removeThreadTagsObject:(AwfulThreadTag*)value_;

- (void)addThreads:(NSSet*)value_;
- (void)removeThreads:(NSSet*)value_;
- (void)addThreadsObject:(AwfulThread*)value_;
- (void)removeThreadsObject:(AwfulThread*)value_;

@end

@interface _AwfulForum (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveDesc;
- (void)setPrimitiveDesc:(NSString*)value;




- (NSNumber*)primitiveExpanded;
- (void)setPrimitiveExpanded:(NSNumber*)value;

- (BOOL)primitiveExpandedValue;
- (void)setPrimitiveExpandedValue:(BOOL)value_;




- (NSString*)primitiveForumID;
- (void)setPrimitiveForumID:(NSString*)value;




- (NSNumber*)primitiveIndex;
- (void)setPrimitiveIndex:(NSNumber*)value;

- (int32_t)primitiveIndexValue;
- (void)setPrimitiveIndexValue:(int32_t)value_;




- (NSNumber*)primitiveIsCategory;
- (void)setPrimitiveIsCategory:(NSNumber*)value;

- (BOOL)primitiveIsCategoryValue;
- (void)setPrimitiveIsCategoryValue:(BOOL)value_;




- (NSString*)primitiveName;
- (void)setPrimitiveName:(NSString*)value;





- (AwfulForum*)primitiveCategory;
- (void)setPrimitiveCategory:(AwfulForum*)value;



- (NSMutableOrderedSet*)primitiveChildren;
- (void)setPrimitiveChildren:(NSMutableOrderedSet*)value;



- (AwfulFavorite*)primitiveFavorite;
- (void)setPrimitiveFavorite:(AwfulFavorite*)value;



- (AwfulForum*)primitiveParentForum;
- (void)setPrimitiveParentForum:(AwfulForum*)value;



- (NSMutableSet*)primitiveThreadTags;
- (void)setPrimitiveThreadTags:(NSMutableSet*)value;



- (NSMutableSet*)primitiveThreads;
- (void)setPrimitiveThreads:(NSMutableSet*)value;


@end
