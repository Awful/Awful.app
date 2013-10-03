// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulCategory.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulCategoryAttributes {
	__unsafe_unretained NSString *categoryID;
	__unsafe_unretained NSString *index;
	__unsafe_unretained NSString *name;
} AwfulCategoryAttributes;

extern const struct AwfulCategoryRelationships {
	__unsafe_unretained NSString *forums;
} AwfulCategoryRelationships;

extern const struct AwfulCategoryFetchedProperties {
} AwfulCategoryFetchedProperties;

@class AwfulForum;





@interface AwfulCategoryID : NSManagedObjectID {}
@end

@interface _AwfulCategory : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulCategoryID*)objectID;





@property (nonatomic, strong) NSString* categoryID;



//- (BOOL)validateCategoryID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* index;



@property int32_t indexValue;
- (int32_t)indexValue;
- (void)setIndexValue:(int32_t)value_;

//- (BOOL)validateIndex:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* name;



//- (BOOL)validateName:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSSet *forums;

- (NSMutableSet*)forumsSet;





@end

@interface _AwfulCategory (CoreDataGeneratedAccessors)

- (void)addForums:(NSSet*)value_;
- (void)removeForums:(NSSet*)value_;
- (void)addForumsObject:(AwfulForum*)value_;
- (void)removeForumsObject:(AwfulForum*)value_;

@end

@interface _AwfulCategory (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveCategoryID;
- (void)setPrimitiveCategoryID:(NSString*)value;




- (NSNumber*)primitiveIndex;
- (void)setPrimitiveIndex:(NSNumber*)value;

- (int32_t)primitiveIndexValue;
- (void)setPrimitiveIndexValue:(int32_t)value_;




- (NSString*)primitiveName;
- (void)setPrimitiveName:(NSString*)value;





- (NSMutableSet*)primitiveForums;
- (void)setPrimitiveForums:(NSMutableSet*)value;


@end
