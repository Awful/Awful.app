// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulEmoticonGroup.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulEmoticonGroupAttributes {
	__unsafe_unretained NSString *desc;
} AwfulEmoticonGroupAttributes;

extern const struct AwfulEmoticonGroupRelationships {
	__unsafe_unretained NSString *emoticons;
} AwfulEmoticonGroupRelationships;

extern const struct AwfulEmoticonGroupFetchedProperties {
} AwfulEmoticonGroupFetchedProperties;

@class AwfulEmoticon;



@interface AwfulEmoticonGroupID : NSManagedObjectID {}
@end

@interface _AwfulEmoticonGroup : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulEmoticonGroupID*)objectID;





@property (nonatomic, strong) NSString* desc;



//- (BOOL)validateDesc:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSSet *emoticons;

- (NSMutableSet*)emoticonsSet;





@end

@interface _AwfulEmoticonGroup (CoreDataGeneratedAccessors)

- (void)addEmoticons:(NSSet*)value_;
- (void)removeEmoticons:(NSSet*)value_;
- (void)addEmoticonsObject:(AwfulEmoticon*)value_;
- (void)removeEmoticonsObject:(AwfulEmoticon*)value_;

@end

@interface _AwfulEmoticonGroup (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveDesc;
- (void)setPrimitiveDesc:(NSString*)value;





- (NSMutableSet*)primitiveEmoticons;
- (void)setPrimitiveEmoticons:(NSMutableSet*)value;


@end
