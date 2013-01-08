// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulPrivateMessage.m instead.

#import "_AwfulPrivateMessage.h"

const struct AwfulPrivateMessageAttributes AwfulPrivateMessageAttributes = {
	.content = @"content",
	.from = @"from",
	.messageID = @"messageID",
	.replied = @"replied",
	.sent = @"sent",
	.subject = @"subject",
	.threadIconImageURL = @"threadIconImageURL",
	.to = @"to",
};

const struct AwfulPrivateMessageRelationships AwfulPrivateMessageRelationships = {
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
	
	if ([key isEqualToString:@"messageIDValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"messageID"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"repliedValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"replied"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic content;






@dynamic from;






@dynamic messageID;



- (int32_t)messageIDValue {
	NSNumber *result = [self messageID];
	return [result intValue];
}

- (void)setMessageIDValue:(int32_t)value_ {
	[self setMessageID:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveMessageIDValue {
	NSNumber *result = [self primitiveMessageID];
	return [result intValue];
}

- (void)setPrimitiveMessageIDValue:(int32_t)value_ {
	[self setPrimitiveMessageID:[NSNumber numberWithInt:value_]];
}





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





@dynamic sent;






@dynamic subject;






@dynamic threadIconImageURL;






@dynamic to;











@end
