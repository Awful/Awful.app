// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulPrivateMessage.m instead.

#import "_AwfulPrivateMessage.h"

const struct AwfulPrivateMessageAttributes AwfulPrivateMessageAttributes = {
	.forwarded = @"forwarded",
	.innerHTML = @"innerHTML",
	.messageID = @"messageID",
	.messageIconImageURL = @"messageIconImageURL",
	.replied = @"replied",
	.seen = @"seen",
	.sentDate = @"sentDate",
	.subject = @"subject",
};

const struct AwfulPrivateMessageRelationships AwfulPrivateMessageRelationships = {
	.from = @"from",
	.to = @"to",
};

const struct AwfulPrivateMessageFetchedProperties AwfulPrivateMessageFetchedProperties = {
};

@implementation AwfulPrivateMessageID
@end

@implementation _AwfulPrivateMessage

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulPrivateMessage" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulPrivateMessage";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulPrivateMessage" inManagedObjectContext:moc_];
}

- (AwfulPrivateMessageID*)objectID {
	return (AwfulPrivateMessageID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"forwardedValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"forwarded"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"repliedValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"replied"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"seenValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"seen"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic forwarded;



- (BOOL)forwardedValue {
	NSNumber *result = [self forwarded];
	return [result boolValue];
}

- (void)setForwardedValue:(BOOL)value_ {
	[self setForwarded:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveForwardedValue {
	NSNumber *result = [self primitiveForwarded];
	return [result boolValue];
}

- (void)setPrimitiveForwardedValue:(BOOL)value_ {
	[self setPrimitiveForwarded:[NSNumber numberWithBool:value_]];
}





@dynamic innerHTML;






@dynamic messageID;






@dynamic messageIconImageURL;






@dynamic replied;



- (BOOL)repliedValue {
	NSNumber *result = [self replied];
	return [result boolValue];
}

- (void)setRepliedValue:(BOOL)value_ {
	[self setReplied:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveRepliedValue {
	NSNumber *result = [self primitiveReplied];
	return [result boolValue];
}

- (void)setPrimitiveRepliedValue:(BOOL)value_ {
	[self setPrimitiveReplied:[NSNumber numberWithBool:value_]];
}





@dynamic seen;



- (BOOL)seenValue {
	NSNumber *result = [self seen];
	return [result boolValue];
}

- (void)setSeenValue:(BOOL)value_ {
	[self setSeen:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveSeenValue {
	NSNumber *result = [self primitiveSeen];
	return [result boolValue];
}

- (void)setPrimitiveSeenValue:(BOOL)value_ {
	[self setPrimitiveSeen:[NSNumber numberWithBool:value_]];
}





@dynamic sentDate;






@dynamic subject;






@dynamic from;

	

@dynamic to;

	






@end
