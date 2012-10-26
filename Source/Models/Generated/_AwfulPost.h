// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulPost.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulPostAttributes {
	__unsafe_unretained NSString *authorAvatarURL;
	__unsafe_unretained NSString *authorCustomTitleHTML;
	__unsafe_unretained NSString *authorIsAModerator;
	__unsafe_unretained NSString *authorIsAnAdministrator;
	__unsafe_unretained NSString *authorIsOriginalPoster;
	__unsafe_unretained NSString *authorName;
	__unsafe_unretained NSString *authorRegDate;
	__unsafe_unretained NSString *beenSeen;
	__unsafe_unretained NSString *editable;
	__unsafe_unretained NSString *innerHTML;
	__unsafe_unretained NSString *postDate;
	__unsafe_unretained NSString *postID;
	__unsafe_unretained NSString *threadIndex;
	__unsafe_unretained NSString *threadPage;
} AwfulPostAttributes;

extern const struct AwfulPostRelationships {
	__unsafe_unretained NSString *thread;
} AwfulPostRelationships;

extern const struct AwfulPostFetchedProperties {
} AwfulPostFetchedProperties;

@class AwfulThread;
















@interface AwfulPostID : NSManagedObjectID {}
@end

@interface _AwfulPost : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulPostID*)objectID;




@property (nonatomic, strong) NSString* authorAvatarURL;


//- (BOOL)validateAuthorAvatarURL:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* authorCustomTitleHTML;


//- (BOOL)validateAuthorCustomTitleHTML:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* authorIsAModerator;


@property BOOL authorIsAModeratorValue;
- (BOOL)authorIsAModeratorValue;
- (void)setAuthorIsAModeratorValue:(BOOL)value_;

//- (BOOL)validateAuthorIsAModerator:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* authorIsAnAdministrator;


@property BOOL authorIsAnAdministratorValue;
- (BOOL)authorIsAnAdministratorValue;
- (void)setAuthorIsAnAdministratorValue:(BOOL)value_;

//- (BOOL)validateAuthorIsAnAdministrator:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* authorIsOriginalPoster;


@property BOOL authorIsOriginalPosterValue;
- (BOOL)authorIsOriginalPosterValue;
- (void)setAuthorIsOriginalPosterValue:(BOOL)value_;

//- (BOOL)validateAuthorIsOriginalPoster:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* authorName;


//- (BOOL)validateAuthorName:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSDate* authorRegDate;


//- (BOOL)validateAuthorRegDate:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* beenSeen;


@property BOOL beenSeenValue;
- (BOOL)beenSeenValue;
- (void)setBeenSeenValue:(BOOL)value_;

//- (BOOL)validateBeenSeen:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* editable;


@property BOOL editableValue;
- (BOOL)editableValue;
- (void)setEditableValue:(BOOL)value_;

//- (BOOL)validateEditable:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* innerHTML;


//- (BOOL)validateInnerHTML:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSDate* postDate;


//- (BOOL)validatePostDate:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* postID;


//- (BOOL)validatePostID:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* threadIndex;


@property int32_t threadIndexValue;
- (int32_t)threadIndexValue;
- (void)setThreadIndexValue:(int32_t)value_;

//- (BOOL)validateThreadIndex:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* threadPage;


@property int32_t threadPageValue;
- (int32_t)threadPageValue;
- (void)setThreadPageValue:(int32_t)value_;

//- (BOOL)validateThreadPage:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulThread* thread;

//- (BOOL)validateThread:(id*)value_ error:(NSError**)error_;





@end

@interface _AwfulPost (CoreDataGeneratedAccessors)

@end

@interface _AwfulPost (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveAuthorAvatarURL;
- (void)setPrimitiveAuthorAvatarURL:(NSString*)value;




- (NSString*)primitiveAuthorCustomTitleHTML;
- (void)setPrimitiveAuthorCustomTitleHTML:(NSString*)value;




- (NSNumber*)primitiveAuthorIsAModerator;
- (void)setPrimitiveAuthorIsAModerator:(NSNumber*)value;

- (BOOL)primitiveAuthorIsAModeratorValue;
- (void)setPrimitiveAuthorIsAModeratorValue:(BOOL)value_;




- (NSNumber*)primitiveAuthorIsAnAdministrator;
- (void)setPrimitiveAuthorIsAnAdministrator:(NSNumber*)value;

- (BOOL)primitiveAuthorIsAnAdministratorValue;
- (void)setPrimitiveAuthorIsAnAdministratorValue:(BOOL)value_;




- (NSNumber*)primitiveAuthorIsOriginalPoster;
- (void)setPrimitiveAuthorIsOriginalPoster:(NSNumber*)value;

- (BOOL)primitiveAuthorIsOriginalPosterValue;
- (void)setPrimitiveAuthorIsOriginalPosterValue:(BOOL)value_;




- (NSString*)primitiveAuthorName;
- (void)setPrimitiveAuthorName:(NSString*)value;




- (NSDate*)primitiveAuthorRegDate;
- (void)setPrimitiveAuthorRegDate:(NSDate*)value;




- (NSNumber*)primitiveBeenSeen;
- (void)setPrimitiveBeenSeen:(NSNumber*)value;

- (BOOL)primitiveBeenSeenValue;
- (void)setPrimitiveBeenSeenValue:(BOOL)value_;




- (NSNumber*)primitiveEditable;
- (void)setPrimitiveEditable:(NSNumber*)value;

- (BOOL)primitiveEditableValue;
- (void)setPrimitiveEditableValue:(BOOL)value_;




- (NSString*)primitiveInnerHTML;
- (void)setPrimitiveInnerHTML:(NSString*)value;




- (NSDate*)primitivePostDate;
- (void)setPrimitivePostDate:(NSDate*)value;




- (NSString*)primitivePostID;
- (void)setPrimitivePostID:(NSString*)value;




- (NSNumber*)primitiveThreadIndex;
- (void)setPrimitiveThreadIndex:(NSNumber*)value;

- (int32_t)primitiveThreadIndexValue;
- (void)setPrimitiveThreadIndexValue:(int32_t)value_;




- (NSNumber*)primitiveThreadPage;
- (void)setPrimitiveThreadPage:(NSNumber*)value;

- (int32_t)primitiveThreadPageValue;
- (void)setPrimitiveThreadPageValue:(int32_t)value_;





- (AwfulThread*)primitiveThread;
- (void)setPrimitiveThread:(AwfulThread*)value;


@end
