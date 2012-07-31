// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulThreadTag.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulThreadTagAttributes {
	__unsafe_unretained NSString *alt;
	__unsafe_unretained NSString *filename;
} AwfulThreadTagAttributes;

extern const struct AwfulThreadTagRelationships {
	__unsafe_unretained NSString *forum;
} AwfulThreadTagRelationships;

extern const struct AwfulThreadTagFetchedProperties {
} AwfulThreadTagFetchedProperties;

@class AwfulForum;




@interface AwfulThreadTagID : NSManagedObjectID {}
@end

@interface _AwfulThreadTag : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulThreadTagID*)objectID;




@property (nonatomic, strong) NSString* alt;


//- (BOOL)validateAlt:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* filename;


//- (BOOL)validateFilename:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSSet* forum;

- (NSMutableSet*)forumSet;





@end

@interface _AwfulThreadTag (CoreDataGeneratedAccessors)

- (void)addForum:(NSSet*)value_;
- (void)removeForum:(NSSet*)value_;
- (void)addForumObject:(AwfulForum*)value_;
- (void)removeForumObject:(AwfulForum*)value_;

@end

@interface _AwfulThreadTag (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveAlt;
- (void)setPrimitiveAlt:(NSString*)value;




- (NSString*)primitiveFilename;
- (void)setPrimitiveFilename:(NSString*)value;





- (NSMutableSet*)primitiveForum;
- (void)setPrimitiveForum:(NSMutableSet*)value;


@end
