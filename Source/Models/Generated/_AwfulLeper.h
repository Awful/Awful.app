// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulLeper.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulLeperAttributes {
	__unsafe_unretained NSString *banID;
	__unsafe_unretained NSString *banType;
	__unsafe_unretained NSString *date;
	__unsafe_unretained NSString *postID;
	__unsafe_unretained NSString *reason;
} AwfulLeperAttributes;

extern const struct AwfulLeperRelationships {
	__unsafe_unretained NSString *admin;
	__unsafe_unretained NSString *jerk;
	__unsafe_unretained NSString *mod;
	__unsafe_unretained NSString *post;
} AwfulLeperRelationships;

extern const struct AwfulLeperFetchedProperties {
} AwfulLeperFetchedProperties;

@class AwfulUser;
@class AwfulUser;
@class AwfulUser;
@class AwfulPost;







@interface AwfulLeperID : NSManagedObjectID {}
@end

@interface _AwfulLeper : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulLeperID*)objectID;





@property (nonatomic, strong) NSString* banID;



//- (BOOL)validateBanID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* banType;



@property int16_t banTypeValue;
- (int16_t)banTypeValue;
- (void)setBanTypeValue:(int16_t)value_;

//- (BOOL)validateBanType:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSDate* date;



//- (BOOL)validateDate:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* postID;



@property int32_t postIDValue;
- (int32_t)postIDValue;
- (void)setPostIDValue:(int32_t)value_;

//- (BOOL)validatePostID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* reason;



//- (BOOL)validateReason:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulUser *admin;

//- (BOOL)validateAdmin:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulUser *jerk;

//- (BOOL)validateJerk:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulUser *mod;

//- (BOOL)validateMod:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulPost *post;

//- (BOOL)validatePost:(id*)value_ error:(NSError**)error_;





@end

@interface _AwfulLeper (CoreDataGeneratedAccessors)

@end

@interface _AwfulLeper (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveBanID;
- (void)setPrimitiveBanID:(NSString*)value;




- (NSNumber*)primitiveBanType;
- (void)setPrimitiveBanType:(NSNumber*)value;

- (int16_t)primitiveBanTypeValue;
- (void)setPrimitiveBanTypeValue:(int16_t)value_;




- (NSDate*)primitiveDate;
- (void)setPrimitiveDate:(NSDate*)value;




- (NSNumber*)primitivePostID;
- (void)setPrimitivePostID:(NSNumber*)value;

- (int32_t)primitivePostIDValue;
- (void)setPrimitivePostIDValue:(int32_t)value_;




- (NSString*)primitiveReason;
- (void)setPrimitiveReason:(NSString*)value;





- (AwfulUser*)primitiveAdmin;
- (void)setPrimitiveAdmin:(AwfulUser*)value;



- (AwfulUser*)primitiveJerk;
- (void)setPrimitiveJerk:(AwfulUser*)value;



- (AwfulUser*)primitiveMod;
- (void)setPrimitiveMod:(AwfulUser*)value;



- (AwfulPost*)primitivePost;
- (void)setPrimitivePost:(AwfulPost*)value;


@end
