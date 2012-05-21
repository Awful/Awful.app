// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulCachedImage.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulCachedImageAttributes {
	__unsafe_unretained NSString *cacheDate;
	__unsafe_unretained NSString *imageData;
	__unsafe_unretained NSString *urlString;
} AwfulCachedImageAttributes;

extern const struct AwfulCachedImageRelationships {
} AwfulCachedImageRelationships;

extern const struct AwfulCachedImageFetchedProperties {
} AwfulCachedImageFetchedProperties;






@interface AwfulCachedImageID : NSManagedObjectID {}
@end

@interface _AwfulCachedImage : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulCachedImageID*)objectID;




@property (nonatomic, strong) NSDate* cacheDate;


//- (BOOL)validateCacheDate:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSData* imageData;


//- (BOOL)validateImageData:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* urlString;


//- (BOOL)validateUrlString:(id*)value_ error:(NSError**)error_;






@end

@interface _AwfulCachedImage (CoreDataGeneratedAccessors)

@end

@interface _AwfulCachedImage (CoreDataGeneratedPrimitiveAccessors)


- (NSDate*)primitiveCacheDate;
- (void)setPrimitiveCacheDate:(NSDate*)value;




- (NSData*)primitiveImageData;
- (void)setPrimitiveImageData:(NSData*)value;




- (NSString*)primitiveUrlString;
- (void)setPrimitiveUrlString:(NSString*)value;




@end
