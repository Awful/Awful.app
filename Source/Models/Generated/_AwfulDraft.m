// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulDraft.m instead.

#import "_AwfulDraft.h"

const struct AwfulDraftAttributes AwfulDraftAttributes = {
	.content = @"content",
	.draftType = @"draftType",
	.optionAddBookmark = @"optionAddBookmark",
	.optionParseURLs = @"optionParseURLs",
	.optionShowSignature = @"optionShowSignature",
	.optionShowSmileys = @"optionShowSmileys",
	.recipient = @"recipient",
	.subject = @"subject",
};

const struct AwfulDraftRelationships AwfulDraftRelationships = {
	.replyToMessage = @"replyToMessage",
	.thread = @"thread",
	.threadTag = @"threadTag",
};

const struct AwfulDraftFetchedProperties AwfulDraftFetchedProperties = {
};

@implementation AwfulDraftID
@end

@implementation _AwfulDraft

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulDraft" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulDraft";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulDraft" inManagedObjectContext:moc_];
}

- (AwfulDraftID*)objectID {
	return (AwfulDraftID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"draftTypeValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"draftType"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"optionAddBookmarkValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"optionAddBookmark"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"optionParseURLsValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"optionParseURLs"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"optionShowSignatureValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"optionShowSignature"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"optionShowSmileysValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"optionShowSmileys"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic content;






@dynamic draftType;



- (int16_t)draftTypeValue {
	NSNumber *result = [self draftType];
	return [result shortValue];
}

- (void)setDraftTypeValue:(int16_t)value_ {
	[self setDraftType:[NSNumber numberWithShort:value_]];
}

- (int16_t)primitiveDraftTypeValue {
	NSNumber *result = [self primitiveDraftType];
	return [result shortValue];
}

- (void)setPrimitiveDraftTypeValue:(int16_t)value_ {
	[self setPrimitiveDraftType:[NSNumber numberWithShort:value_]];
}





@dynamic optionAddBookmark;



- (BOOL)optionAddBookmarkValue {
	NSNumber *result = [self optionAddBookmark];
	return [result boolValue];
}

- (void)setOptionAddBookmarkValue:(BOOL)value_ {
	[self setOptionAddBookmark:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveOptionAddBookmarkValue {
	NSNumber *result = [self primitiveOptionAddBookmark];
	return [result boolValue];
}

- (void)setPrimitiveOptionAddBookmarkValue:(BOOL)value_ {
	[self setPrimitiveOptionAddBookmark:[NSNumber numberWithBool:value_]];
}





@dynamic optionParseURLs;



- (BOOL)optionParseURLsValue {
	NSNumber *result = [self optionParseURLs];
	return [result boolValue];
}

- (void)setOptionParseURLsValue:(BOOL)value_ {
	[self setOptionParseURLs:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveOptionParseURLsValue {
	NSNumber *result = [self primitiveOptionParseURLs];
	return [result boolValue];
}

- (void)setPrimitiveOptionParseURLsValue:(BOOL)value_ {
	[self setPrimitiveOptionParseURLs:[NSNumber numberWithBool:value_]];
}





@dynamic optionShowSignature;



- (BOOL)optionShowSignatureValue {
	NSNumber *result = [self optionShowSignature];
	return [result boolValue];
}

- (void)setOptionShowSignatureValue:(BOOL)value_ {
	[self setOptionShowSignature:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveOptionShowSignatureValue {
	NSNumber *result = [self primitiveOptionShowSignature];
	return [result boolValue];
}

- (void)setPrimitiveOptionShowSignatureValue:(BOOL)value_ {
	[self setPrimitiveOptionShowSignature:[NSNumber numberWithBool:value_]];
}





@dynamic optionShowSmileys;



- (BOOL)optionShowSmileysValue {
	NSNumber *result = [self optionShowSmileys];
	return [result boolValue];
}

- (void)setOptionShowSmileysValue:(BOOL)value_ {
	[self setOptionShowSmileys:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveOptionShowSmileysValue {
	NSNumber *result = [self primitiveOptionShowSmileys];
	return [result boolValue];
}

- (void)setPrimitiveOptionShowSmileysValue:(BOOL)value_ {
	[self setPrimitiveOptionShowSmileys:[NSNumber numberWithBool:value_]];
}





@dynamic recipient;






@dynamic subject;






@dynamic replyToMessage;

	

@dynamic thread;

	

@dynamic threadTag;

	






@end
