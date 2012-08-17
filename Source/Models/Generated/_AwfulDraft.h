// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulDraft.h instead.

#import <CoreData/CoreData.h>


extern const struct AwfulDraftAttributes {
	__unsafe_unretained NSString *content;
	__unsafe_unretained NSString *draftType;
	__unsafe_unretained NSString *optionAddBookmark;
	__unsafe_unretained NSString *optionParseURLs;
	__unsafe_unretained NSString *optionShowSignature;
	__unsafe_unretained NSString *optionShowSmileys;
	__unsafe_unretained NSString *recipient;
	__unsafe_unretained NSString *subject;
} AwfulDraftAttributes;

extern const struct AwfulDraftRelationships {
	__unsafe_unretained NSString *replyToMessage;
	__unsafe_unretained NSString *thread;
	__unsafe_unretained NSString *threadTag;
} AwfulDraftRelationships;

extern const struct AwfulDraftFetchedProperties {
} AwfulDraftFetchedProperties;

@class AwfulPM;
@class AwfulThread;
@class AwfulThreadTag;










@interface AwfulDraftID : NSManagedObjectID {}
@end

@interface _AwfulDraft : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (AwfulDraftID*)objectID;




@property (nonatomic, strong) NSString* content;


//- (BOOL)validateContent:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* draftType;


@property int16_t draftTypeValue;
- (int16_t)draftTypeValue;
- (void)setDraftTypeValue:(int16_t)value_;

//- (BOOL)validateDraftType:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* optionAddBookmark;


@property BOOL optionAddBookmarkValue;
- (BOOL)optionAddBookmarkValue;
- (void)setOptionAddBookmarkValue:(BOOL)value_;

//- (BOOL)validateOptionAddBookmark:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* optionParseURLs;


@property BOOL optionParseURLsValue;
- (BOOL)optionParseURLsValue;
- (void)setOptionParseURLsValue:(BOOL)value_;

//- (BOOL)validateOptionParseURLs:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* optionShowSignature;


@property BOOL optionShowSignatureValue;
- (BOOL)optionShowSignatureValue;
- (void)setOptionShowSignatureValue:(BOOL)value_;

//- (BOOL)validateOptionShowSignature:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSNumber* optionShowSmileys;


@property BOOL optionShowSmileysValue;
- (BOOL)optionShowSmileysValue;
- (void)setOptionShowSmileysValue:(BOOL)value_;

//- (BOOL)validateOptionShowSmileys:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* recipient;


//- (BOOL)validateRecipient:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) NSString* subject;


//- (BOOL)validateSubject:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) AwfulPM* replyToMessage;

//- (BOOL)validateReplyToMessage:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulThread* thread;

//- (BOOL)validateThread:(id*)value_ error:(NSError**)error_;




@property (nonatomic, strong) AwfulThreadTag* threadTag;

//- (BOOL)validateThreadTag:(id*)value_ error:(NSError**)error_;





@end

@interface _AwfulDraft (CoreDataGeneratedAccessors)

@end

@interface _AwfulDraft (CoreDataGeneratedPrimitiveAccessors)


- (NSString*)primitiveContent;
- (void)setPrimitiveContent:(NSString*)value;




- (NSNumber*)primitiveDraftType;
- (void)setPrimitiveDraftType:(NSNumber*)value;

- (int16_t)primitiveDraftTypeValue;
- (void)setPrimitiveDraftTypeValue:(int16_t)value_;




- (NSNumber*)primitiveOptionAddBookmark;
- (void)setPrimitiveOptionAddBookmark:(NSNumber*)value;

- (BOOL)primitiveOptionAddBookmarkValue;
- (void)setPrimitiveOptionAddBookmarkValue:(BOOL)value_;




- (NSNumber*)primitiveOptionParseURLs;
- (void)setPrimitiveOptionParseURLs:(NSNumber*)value;

- (BOOL)primitiveOptionParseURLsValue;
- (void)setPrimitiveOptionParseURLsValue:(BOOL)value_;




- (NSNumber*)primitiveOptionShowSignature;
- (void)setPrimitiveOptionShowSignature:(NSNumber*)value;

- (BOOL)primitiveOptionShowSignatureValue;
- (void)setPrimitiveOptionShowSignatureValue:(BOOL)value_;




- (NSNumber*)primitiveOptionShowSmileys;
- (void)setPrimitiveOptionShowSmileys:(NSNumber*)value;

- (BOOL)primitiveOptionShowSmileysValue;
- (void)setPrimitiveOptionShowSmileysValue:(BOOL)value_;




- (NSString*)primitiveRecipient;
- (void)setPrimitiveRecipient:(NSString*)value;




- (NSString*)primitiveSubject;
- (void)setPrimitiveSubject:(NSString*)value;





- (AwfulPM*)primitiveReplyToMessage;
- (void)setPrimitiveReplyToMessage:(AwfulPM*)value;



- (AwfulThread*)primitiveThread;
- (void)setPrimitiveThread:(AwfulThread*)value;



- (AwfulThreadTag*)primitiveThreadTag;
- (void)setPrimitiveThreadTag:(AwfulThreadTag*)value;


@end
