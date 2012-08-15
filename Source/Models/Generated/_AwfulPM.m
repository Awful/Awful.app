// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulPM.m instead.

#import "_AwfulPM.h"

const struct AwfulPMAttributes AwfulPMAttributes = {
	.content = @"content",
	.from = @"from",
	.messageID = @"messageID",
	.replied = @"replied",
	.sent = @"sent",
	.subject = @"subject",
	.to = @"to",
};

const struct AwfulPMRelationships AwfulPMRelationships = {
	.threadTag = @"threadTag",
};

const struct AwfulPMFetchedProperties AwfulPMFetchedProperties = {
};

@implementation AwfulPMID
@end

@implementation _AwfulPM

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulPM" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulPM";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulPM" inManagedObjectContext:moc_];
}

- (AwfulPMID*)objectID {
	return (AwfulPMID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"messageIDValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"messageID"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"repliedValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"replied"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
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






@dynamic to;






@dynamic threadTag;

	






@end
