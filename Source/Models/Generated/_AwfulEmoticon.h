// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulEmoticon.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulEmoticonAttributes {
	__unsafe_unretained NSString *cachedPath;
	__unsafe_unretained NSString *code;
	__unsafe_unretained NSString *desc;
	__unsafe_unretained NSString *height;
	__unsafe_unretained NSString *urlString;
	__unsafe_unretained NSString *usageCount;
	__unsafe_unretained NSString *width;
} AwfulEmoticonAttributes;

extern const struct AwfulEmoticonRelationships {
	__unsafe_unretained NSString *group;
} AwfulEmoticonRelationships;

extern const struct AwfulEmoticonFetchedProperties {
} AwfulEmoticonFetchedProperties;

@class AwfulEmoticonGroup;









@interface AwfulEmoticonID : NSManagedObjectID {}
@end

@interface _AwfulEmoticon : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulEmoticonID*)objectID;





@property (nonatomic, strong) NSString* cachedPath;



//- (BOOL)validateCachedPath:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* code;



//- (BOOL)validateCode:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* desc;



//- (BOOL)validateDesc:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* height;



@property int32_t heightValue;
- (int32_t)heightValue;
- (void)setHeightValue:(int32_t)value_;

//- (BOOL)validateHeight:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* urlString;



//- (BOOL)validateUrlString:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* usageCount;



@property int32_t usageCountValue;
- (int32_t)usageCountValue;
- (void)setUsageCountValue:(int32_t)value_;

//- (BOOL)validateUsageCount:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* width;



@property int32_t widthValue;
- (int32_t)widthValue;
- (void)setWidthValue:(int32_t)value_;

//- (BOOL)validateWidth:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulEmoticonGroup *group;

//- (BOOL)validateGroup:(id*)value_ error:(NSError**)error_;





@end

@interface _AwfulEmoticon (CoreDataGeneratedAccessors)

@end

@interface _AwfulEmoticon (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveCachedPath;
- (void)setPrimitiveCachedPath:(NSString*)value;




- (NSString*)primitiveCode;
- (void)setPrimitiveCode:(NSString*)value;




- (NSString*)primitiveDesc;
- (void)setPrimitiveDesc:(NSString*)value;




- (NSNumber*)primitiveHeight;
- (void)setPrimitiveHeight:(NSNumber*)value;

- (int32_t)primitiveHeightValue;
- (void)setPrimitiveHeightValue:(int32_t)value_;




- (NSString*)primitiveUrlString;
- (void)setPrimitiveUrlString:(NSString*)value;




- (NSNumber*)primitiveUsageCount;
- (void)setPrimitiveUsageCount:(NSNumber*)value;

- (int32_t)primitiveUsageCountValue;
- (void)setPrimitiveUsageCountValue:(int32_t)value_;




- (NSNumber*)primitiveWidth;
- (void)setPrimitiveWidth:(NSNumber*)value;

- (int32_t)primitiveWidthValue;
- (void)setPrimitiveWidthValue:(int32_t)value_;





- (AwfulEmoticonGroup*)primitiveGroup;
- (void)setPrimitiveGroup:(AwfulEmoticonGroup*)value;


@end
