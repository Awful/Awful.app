// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulLogEntry.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulLogEntryAttributes {
	__unsafe_unretained NSString *category;
	__unsafe_unretained NSString *date;
	__unsafe_unretained NSString *message;
} AwfulLogEntryAttributes;

extern const struct AwfulLogEntryRelationships {
} AwfulLogEntryRelationships;

extern const struct AwfulLogEntryFetchedProperties {
} AwfulLogEntryFetchedProperties;






@interface AwfulLogEntryID : NSManagedObjectID {}
@end

@interface _AwfulLogEntry : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulLogEntryID*)objectID;




@property (nonatomic, strong) NSString* category;


//- (BOOL)validateCategory:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSDate* date;


//- (BOOL)validateDate:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* message;


//- (BOOL)validateMessage:(id*)value_ error:(NSError**)error_;






@end

@interface _AwfulLogEntry (CoreDataGeneratedAccessors)

@end

@interface _AwfulLogEntry (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveCategory;
- (void)setPrimitiveCategory:(NSString*)value;




- (NSDate*)primitiveDate;
- (void)setPrimitiveDate:(NSDate*)value;




- (NSString*)primitiveMessage;
- (void)setPrimitiveMessage:(NSString*)value;




@end
