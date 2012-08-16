// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulThreadTag.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulThreadTagAttributes {
	__unsafe_unretained NSString *alt;
	__unsafe_unretained NSString *filename;
	__unsafe_unretained NSString *tagID;
} AwfulThreadTagAttributes;

extern const struct AwfulThreadTagRelationships {
	__unsafe_unretained NSString *forums;
	__unsafe_unretained NSString *threads;
} AwfulThreadTagRelationships;

extern const struct AwfulThreadTagFetchedProperties {
} AwfulThreadTagFetchedProperties;

@class AwfulForum;
@class AwfulThread;





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




@property (nonatomic, strong) NSNumber* tagID;


@property int16_t tagIDValue;
- (int16_t)tagIDValue;
- (void)setTagIDValue:(int16_t)value_;

//- (BOOL)validateTagID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSSet* forums;

- (NSMutableSet*)forumsSet;




@property (nonatomic, strong) NSSet* threads;

- (NSMutableSet*)threadsSet;





@end

@interface _AwfulThreadTag (CoreDataGeneratedAccessors)

- (void)addForums:(NSSet*)value_;
- (void)removeForums:(NSSet*)value_;
- (void)addForumsObject:(AwfulForum*)value_;
- (void)removeForumsObject:(AwfulForum*)value_;

- (void)addThreads:(NSSet*)value_;
- (void)removeThreads:(NSSet*)value_;
- (void)addThreadsObject:(AwfulThread*)value_;
- (void)removeThreadsObject:(AwfulThread*)value_;

@end

@interface _AwfulThreadTag (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveAlt;
- (void)setPrimitiveAlt:(NSString*)value;




- (NSString*)primitiveFilename;
- (void)setPrimitiveFilename:(NSString*)value;




- (NSNumber*)primitiveTagID;
- (void)setPrimitiveTagID:(NSNumber*)value;

- (int16_t)primitiveTagIDValue;
- (void)setPrimitiveTagIDValue:(int16_t)value_;





- (NSMutableSet*)primitiveForums;
- (void)setPrimitiveForums:(NSMutableSet*)value;



- (NSMutableSet*)primitiveThreads;
- (void)setPrimitiveThreads:(NSMutableSet*)value;


@end
