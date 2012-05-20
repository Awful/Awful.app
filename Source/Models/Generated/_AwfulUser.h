// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulUser.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulUserAttributes {
	__unsafe_unretained NSString *postsPerPage;
	__unsafe_unretained NSString *userID;
	__unsafe_unretained NSString *userName;
} AwfulUserAttributes;

extern const struct AwfulUserRelationships {
} AwfulUserRelationships;

extern const struct AwfulUserFetchedProperties {
} AwfulUserFetchedProperties;






@interface AwfulUserID : NSManagedObjectID {}
@end

@interface _AwfulUser : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulUserID*)objectID;




@property (nonatomic, strong) NSNumber* postsPerPage;


@property int32_t postsPerPageValue;
- (int32_t)postsPerPageValue;
- (void)setPostsPerPageValue:(int32_t)value_;

//- (BOOL)validatePostsPerPage:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* userID;


//- (BOOL)validateUserID:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* userName;


//- (BOOL)validateUserName:(id*)value_ error:(NSError**)error_;






@end

@interface _AwfulUser (CoreDataGeneratedAccessors)

@end

@interface _AwfulUser (CoreDataGeneratedPrimitiveAccessors)


- (NSNumber*)primitivePostsPerPage;
- (void)setPrimitivePostsPerPage:(NSNumber*)value;

- (int32_t)primitivePostsPerPageValue;
- (void)setPrimitivePostsPerPageValue:(int32_t)value_;




- (NSString*)primitiveUserID;
- (void)setPrimitiveUserID:(NSString*)value;




- (NSString*)primitiveUserName;
- (void)setPrimitiveUserName:(NSString*)value;




@end
