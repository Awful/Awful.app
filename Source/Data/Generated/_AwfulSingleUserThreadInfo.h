// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulSingleUserThreadInfo.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulSingleUserThreadInfoAttributes {
	__unsafe_unretained NSString *numberOfPages;
} AwfulSingleUserThreadInfoAttributes;

extern const struct AwfulSingleUserThreadInfoRelationships {
	__unsafe_unretained NSString *author;
	__unsafe_unretained NSString *thread;
} AwfulSingleUserThreadInfoRelationships;

extern const struct AwfulSingleUserThreadInfoFetchedProperties {
} AwfulSingleUserThreadInfoFetchedProperties;

@class AwfulUser;
@class AwfulThread;



@interface AwfulSingleUserThreadInfoID : NSManagedObjectID {}
@end

@interface _AwfulSingleUserThreadInfo : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulSingleUserThreadInfoID*)objectID;





@property (nonatomic, strong) NSNumber* numberOfPages;



@property int32_t numberOfPagesValue;
- (int32_t)numberOfPagesValue;
- (void)setNumberOfPagesValue:(int32_t)value_;

//- (BOOL)validateNumberOfPages:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulUser *author;

//- (BOOL)validateAuthor:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulThread *thread;

//- (BOOL)validateThread:(id*)value_ error:(NSError**)error_;





@end

@interface _AwfulSingleUserThreadInfo (CoreDataGeneratedAccessors)

@end

@interface _AwfulSingleUserThreadInfo (CoreDataGeneratedPrimitiveAccessors)


- (NSNumber*)primitiveNumberOfPages;
- (void)setPrimitiveNumberOfPages:(NSNumber*)value;

- (int32_t)primitiveNumberOfPagesValue;
- (void)setPrimitiveNumberOfPagesValue:(int32_t)value_;





- (AwfulUser*)primitiveAuthor;
- (void)setPrimitiveAuthor:(AwfulUser*)value;



- (AwfulThread*)primitiveThread;
- (void)setPrimitiveThread:(AwfulThread*)value;


@end
