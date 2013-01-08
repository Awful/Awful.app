// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulPrivateMessage.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulPrivateMessageAttributes {
	__unsafe_unretained NSString *content;
	__unsafe_unretained NSString *from;
	__unsafe_unretained NSString *messageID;
	__unsafe_unretained NSString *replied;
	__unsafe_unretained NSString *sent;
	__unsafe_unretained NSString *subject;
	__unsafe_unretained NSString *threadIconImageURL;
	__unsafe_unretained NSString *to;
} AwfulPrivateMessageAttributes;

extern const struct AwfulPrivateMessageRelationships {
} AwfulPrivateMessageRelationships;

extern const struct AwfulPrivateMessageFetchedProperties {
} AwfulPrivateMessageFetchedProperties;








@class NSObject;


@interface AwfulPrivateMessageID : NSManagedObjectID {}
@end

@interface _AwfulPrivateMessage : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulPrivateMessageID*)objectID;





@property (nonatomic, strong) NSString* content;



//- (BOOL)validateContent:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* from;



//- (BOOL)validateFrom:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* messageID;



@property int32_t messageIDValue;
- (int32_t)messageIDValue;
- (void)setMessageIDValue:(int32_t)value_;

//- (BOOL)validateMessageID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* replied;



@property BOOL repliedValue;
- (BOOL)repliedValue;
- (void)setRepliedValue:(BOOL)value_;

//- (BOOL)validateReplied:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSDate* sent;



//- (BOOL)validateSent:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* subject;



//- (BOOL)validateSubject:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) id threadIconImageURL;



//- (BOOL)validateThreadIconImageURL:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* to;



//- (BOOL)validateTo:(id*)value_ error:(NSError**)error_;






@end

@interface _AwfulPrivateMessage (CoreDataGeneratedAccessors)

@end

@interface _AwfulPrivateMessage (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveContent;
- (void)setPrimitiveContent:(NSString*)value;




- (NSString*)primitiveFrom;
- (void)setPrimitiveFrom:(NSString*)value;




- (NSNumber*)primitiveMessageID;
- (void)setPrimitiveMessageID:(NSNumber*)value;

- (int32_t)primitiveMessageIDValue;
- (void)setPrimitiveMessageIDValue:(int32_t)value_;




- (NSNumber*)primitiveReplied;
- (void)setPrimitiveReplied:(NSNumber*)value;

- (BOOL)primitiveRepliedValue;
- (void)setPrimitiveRepliedValue:(BOOL)value_;




- (NSDate*)primitiveSent;
- (void)setPrimitiveSent:(NSDate*)value;




- (NSString*)primitiveSubject;
- (void)setPrimitiveSubject:(NSString*)value;




- (id)primitiveThreadIconImageURL;
- (void)setPrimitiveThreadIconImageURL:(id)value;




- (NSString*)primitiveTo;
- (void)setPrimitiveTo:(NSString*)value;




@end
