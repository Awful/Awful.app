// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulPost.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulPostAttributes {
	__unsafe_unretained NSString *beenSeen;
	__unsafe_unretained NSString *editable;
	__unsafe_unretained NSString *innerHTML;
	__unsafe_unretained NSString *postDate;
	__unsafe_unretained NSString *postID;
	__unsafe_unretained NSString *threadIndex;
	__unsafe_unretained NSString *threadPage;
} AwfulPostAttributes;

extern const struct AwfulPostRelationships {
	__unsafe_unretained NSString *author;
	__unsafe_unretained NSString *thread;
} AwfulPostRelationships;

extern const struct AwfulPostFetchedProperties {
} AwfulPostFetchedProperties;

@class AwfulUser;
@class AwfulThread;









@interface AwfulPostID : NSManagedObjectID {}
@end

@interface _AwfulPost : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulPostID*)objectID;





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





@property (nonatomic, strong) AwfulUser *author;

//- (BOOL)validateAuthor:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulThread *thread;

//- (BOOL)validateThread:(id*)value_ error:(NSError**)error_;





@end

@interface _AwfulPost (CoreDataGeneratedAccessors)

@end

@interface _AwfulPost (CoreDataGeneratedPrimitiveAccessors)


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





- (AwfulUser*)primitiveAuthor;
- (void)setPrimitiveAuthor:(AwfulUser*)value;



- (AwfulThread*)primitiveThread;
- (void)setPrimitiveThread:(AwfulThread*)value;


@end
