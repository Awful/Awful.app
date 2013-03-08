// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulPrivateMessage.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulPrivateMessageAttributes {
	__unsafe_unretained NSString *forwarded;
	__unsafe_unretained NSString *innerHTML;
	__unsafe_unretained NSString *messageID;
	__unsafe_unretained NSString *messageIconImageURL;
	__unsafe_unretained NSString *replied;
	__unsafe_unretained NSString *seen;
	__unsafe_unretained NSString *sentDate;
	__unsafe_unretained NSString *subject;
} AwfulPrivateMessageAttributes;

extern const struct AwfulPrivateMessageRelationships {
	__unsafe_unretained NSString *from;
	__unsafe_unretained NSString *to;
} AwfulPrivateMessageRelationships;

extern const struct AwfulPrivateMessageFetchedProperties {
} AwfulPrivateMessageFetchedProperties;

@class AwfulUser;
@class AwfulUser;




@class NSObject;





@interface AwfulPrivateMessageID : NSManagedObjectID {}
@end

@interface _AwfulPrivateMessage : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulPrivateMessageID*)objectID;





@property (nonatomic, strong) NSNumber* forwarded;



@property BOOL forwardedValue;
- (BOOL)forwardedValue;
- (void)setForwardedValue:(BOOL)value_;

//- (BOOL)validateForwarded:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* innerHTML;



//- (BOOL)validateInnerHTML:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* messageID;



//- (BOOL)validateMessageID:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) id messageIconImageURL;



//- (BOOL)validateMessageIconImageURL:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* replied;



@property BOOL repliedValue;
- (BOOL)repliedValue;
- (void)setRepliedValue:(BOOL)value_;

//- (BOOL)validateReplied:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* seen;



@property BOOL seenValue;
- (BOOL)seenValue;
- (void)setSeenValue:(BOOL)value_;

//- (BOOL)validateSeen:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSDate* sentDate;



//- (BOOL)validateSentDate:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* subject;



//- (BOOL)validateSubject:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulUser *from;

//- (BOOL)validateFrom:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulUser *to;

//- (BOOL)validateTo:(id*)value_ error:(NSError**)error_;





@end

@interface _AwfulPrivateMessage (CoreDataGeneratedAccessors)

@end

@interface _AwfulPrivateMessage (CoreDataGeneratedPrimitiveAccessors)


- (NSNumber*)primitiveForwarded;
- (void)setPrimitiveForwarded:(NSNumber*)value;

- (BOOL)primitiveForwardedValue;
- (void)setPrimitiveForwardedValue:(BOOL)value_;




- (NSString*)primitiveInnerHTML;
- (void)setPrimitiveInnerHTML:(NSString*)value;




- (NSString*)primitiveMessageID;
- (void)setPrimitiveMessageID:(NSString*)value;




- (id)primitiveMessageIconImageURL;
- (void)setPrimitiveMessageIconImageURL:(id)value;




- (NSNumber*)primitiveReplied;
- (void)setPrimitiveReplied:(NSNumber*)value;

- (BOOL)primitiveRepliedValue;
- (void)setPrimitiveRepliedValue:(BOOL)value_;




- (NSNumber*)primitiveSeen;
- (void)setPrimitiveSeen:(NSNumber*)value;

- (BOOL)primitiveSeenValue;
- (void)setPrimitiveSeenValue:(BOOL)value_;




- (NSDate*)primitiveSentDate;
- (void)setPrimitiveSentDate:(NSDate*)value;




- (NSString*)primitiveSubject;
- (void)setPrimitiveSubject:(NSString*)value;





- (AwfulUser*)primitiveFrom;
- (void)setPrimitiveFrom:(AwfulUser*)value;



- (AwfulUser*)primitiveTo;
- (void)setPrimitiveTo:(AwfulUser*)value;


@end
