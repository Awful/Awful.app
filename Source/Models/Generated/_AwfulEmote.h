// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulEmote.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulEmoteAttributes {
	__unsafe_unretained NSString *code;
	__unsafe_unretained NSString *desc;
	__unsafe_unretained NSString *filename;
} AwfulEmoteAttributes;

extern const struct AwfulEmoteRelationships {
} AwfulEmoteRelationships;

extern const struct AwfulEmoteFetchedProperties {
} AwfulEmoteFetchedProperties;






@interface AwfulEmoteID : NSManagedObjectID {}
@end

@interface _AwfulEmote : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulEmoteID*)objectID;




@property (nonatomic, strong) NSString* code;


//- (BOOL)validateCode:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* desc;


//- (BOOL)validateDesc:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* filename;


//- (BOOL)validateFilename:(id*)value_ error:(NSError**)error_;






@end

@interface _AwfulEmote (CoreDataGeneratedAccessors)

@end

@interface _AwfulEmote (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveCode;
- (void)setPrimitiveCode:(NSString*)value;




- (NSString*)primitiveDesc;
- (void)setPrimitiveDesc:(NSString*)value;




- (NSString*)primitiveFilename;
- (void)setPrimitiveFilename:(NSString*)value;




@end
