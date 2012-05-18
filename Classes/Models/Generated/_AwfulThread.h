// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulThread.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulThreadAttributes {
	__unsafe_unretained NSString *authorName;
	__unsafe_unretained NSString *isBookmarked;
	__unsafe_unretained NSString *isLocked;
	__unsafe_unretained NSString *lastPostAuthorName;
	__unsafe_unretained NSString *lastPostDate;
	__unsafe_unretained NSString *seen;
	__unsafe_unretained NSString *starCategory;
	__unsafe_unretained NSString *stickyIndex;
	__unsafe_unretained NSString *threadID;
	__unsafe_unretained NSString *threadIconImageURL;
	__unsafe_unretained NSString *threadIconImageURL2;
	__unsafe_unretained NSString *threadRating;
	__unsafe_unretained NSString *title;
	__unsafe_unretained NSString *totalReplies;
	__unsafe_unretained NSString *totalUnreadPosts;
} AwfulThreadAttributes;

extern const struct AwfulThreadRelationships {
	__unsafe_unretained NSString *forum;
} AwfulThreadRelationships;

extern const struct AwfulThreadFetchedProperties {
} AwfulThreadFetchedProperties;

@class AwfulForum;










@class NSObject;
@class NSObject;





@interface AwfulThreadID : NSManagedObjectID {}
@end

@interface _AwfulThread : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulThreadID*)objectID;




@property (nonatomic, strong) NSString* authorName;


//- (BOOL)validateAuthorName:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* isBookmarked;


@property BOOL isBookmarkedValue;
- (BOOL)isBookmarkedValue;
- (void)setIsBookmarkedValue:(BOOL)value_;

//- (BOOL)validateIsBookmarked:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* isLocked;


@property BOOL isLockedValue;
- (BOOL)isLockedValue;
- (void)setIsLockedValue:(BOOL)value_;

//- (BOOL)validateIsLocked:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* lastPostAuthorName;


//- (BOOL)validateLastPostAuthorName:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSDate* lastPostDate;


//- (BOOL)validateLastPostDate:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* seen;


@property BOOL seenValue;
- (BOOL)seenValue;
- (void)setSeenValue:(BOOL)value_;

//- (BOOL)validateSeen:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* starCategory;


@property int16_t starCategoryValue;
- (int16_t)starCategoryValue;
- (void)setStarCategoryValue:(int16_t)value_;

//- (BOOL)validateStarCategory:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* stickyIndex;


@property int32_t stickyIndexValue;
- (int32_t)stickyIndexValue;
- (void)setStickyIndexValue:(int32_t)value_;

//- (BOOL)validateStickyIndex:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* threadID;


//- (BOOL)validateThreadID:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) id threadIconImageURL;


//- (BOOL)validateThreadIconImageURL:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) id threadIconImageURL2;


//- (BOOL)validateThreadIconImageURL2:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* threadRating;


@property int16_t threadRatingValue;
- (int16_t)threadRatingValue;
- (void)setThreadRatingValue:(int16_t)value_;

//- (BOOL)validateThreadRating:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* title;


//- (BOOL)validateTitle:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* totalReplies;


@property int32_t totalRepliesValue;
- (int32_t)totalRepliesValue;
- (void)setTotalRepliesValue:(int32_t)value_;

//- (BOOL)validateTotalReplies:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* totalUnreadPosts;


@property int32_t totalUnreadPostsValue;
- (int32_t)totalUnreadPostsValue;
- (void)setTotalUnreadPostsValue:(int32_t)value_;

//- (BOOL)validateTotalUnreadPosts:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulForum* forum;

//- (BOOL)validateForum:(id*)value_ error:(NSError**)error_;





@end

@interface _AwfulThread (CoreDataGeneratedAccessors)

@end

@interface _AwfulThread (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveAuthorName;
- (void)setPrimitiveAuthorName:(NSString*)value;




- (NSNumber*)primitiveIsBookmarked;
- (void)setPrimitiveIsBookmarked:(NSNumber*)value;

- (BOOL)primitiveIsBookmarkedValue;
- (void)setPrimitiveIsBookmarkedValue:(BOOL)value_;




- (NSNumber*)primitiveIsLocked;
- (void)setPrimitiveIsLocked:(NSNumber*)value;

- (BOOL)primitiveIsLockedValue;
- (void)setPrimitiveIsLockedValue:(BOOL)value_;




- (NSString*)primitiveLastPostAuthorName;
- (void)setPrimitiveLastPostAuthorName:(NSString*)value;




- (NSDate*)primitiveLastPostDate;
- (void)setPrimitiveLastPostDate:(NSDate*)value;




- (NSNumber*)primitiveSeen;
- (void)setPrimitiveSeen:(NSNumber*)value;

- (BOOL)primitiveSeenValue;
- (void)setPrimitiveSeenValue:(BOOL)value_;




- (NSNumber*)primitiveStarCategory;
- (void)setPrimitiveStarCategory:(NSNumber*)value;

- (int16_t)primitiveStarCategoryValue;
- (void)setPrimitiveStarCategoryValue:(int16_t)value_;




- (NSNumber*)primitiveStickyIndex;
- (void)setPrimitiveStickyIndex:(NSNumber*)value;

- (int32_t)primitiveStickyIndexValue;
- (void)setPrimitiveStickyIndexValue:(int32_t)value_;




- (NSString*)primitiveThreadID;
- (void)setPrimitiveThreadID:(NSString*)value;




- (id)primitiveThreadIconImageURL;
- (void)setPrimitiveThreadIconImageURL:(id)value;




- (id)primitiveThreadIconImageURL2;
- (void)setPrimitiveThreadIconImageURL2:(id)value;




- (NSNumber*)primitiveThreadRating;
- (void)setPrimitiveThreadRating:(NSNumber*)value;

- (int16_t)primitiveThreadRatingValue;
- (void)setPrimitiveThreadRatingValue:(int16_t)value_;




- (NSString*)primitiveTitle;
- (void)setPrimitiveTitle:(NSString*)value;




- (NSNumber*)primitiveTotalReplies;
- (void)setPrimitiveTotalReplies:(NSNumber*)value;

- (int32_t)primitiveTotalRepliesValue;
- (void)setPrimitiveTotalRepliesValue:(int32_t)value_;




- (NSNumber*)primitiveTotalUnreadPosts;
- (void)setPrimitiveTotalUnreadPosts:(NSNumber*)value;

- (int32_t)primitiveTotalUnreadPostsValue;
- (void)setPrimitiveTotalUnreadPostsValue:(int32_t)value_;





- (AwfulForum*)primitiveForum;
- (void)setPrimitiveForum:(AwfulForum*)value;


@end
