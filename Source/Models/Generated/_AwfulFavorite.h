// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulFavorite.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulFavoriteAttributes {
	__unsafe_unretained NSString *displayOrder;
} AwfulFavoriteAttributes;

extern const struct AwfulFavoriteRelationships {
	__unsafe_unretained NSString *forum;
} AwfulFavoriteRelationships;

extern const struct AwfulFavoriteFetchedProperties {
} AwfulFavoriteFetchedProperties;

@class AwfulForum;



@interface AwfulFavoriteID : NSManagedObjectID {}
@end

@interface _AwfulFavorite : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulFavoriteID*)objectID;




@property (nonatomic, strong) NSNumber* displayOrder;


@property int32_t displayOrderValue;
- (int32_t)displayOrderValue;
- (void)setDisplayOrderValue:(int32_t)value_;

//- (BOOL)validateDisplayOrder:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulForum* forum;

//- (BOOL)validateForum:(id*)value_ error:(NSError**)error_;





@end

@interface _AwfulFavorite (CoreDataGeneratedAccessors)

@end

@interface _AwfulFavorite (CoreDataGeneratedPrimitiveAccessors)


- (NSNumber*)primitiveDisplayOrder;
- (void)setPrimitiveDisplayOrder:(NSNumber*)value;

- (int32_t)primitiveDisplayOrderValue;
- (void)setPrimitiveDisplayOrderValue:(int32_t)value_;





- (AwfulForum*)primitiveForum;
- (void)setPrimitiveForum:(AwfulForum*)value;


@end
