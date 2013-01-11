// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulPost.m instead.

#import "_AwfulPost.h"

const struct AwfulPostAttributes AwfulPostAttributes = {
	.beenSeen = @"beenSeen",
	.editable = @"editable",
	.innerHTML = @"innerHTML",
	.postDate = @"postDate",
	.postID = @"postID",
	.threadIndex = @"threadIndex",
	.threadPage = @"threadPage",
};

const struct AwfulPostRelationships AwfulPostRelationships = {
	.author = @"author",
	.thread = @"thread",
};

const struct AwfulPostFetchedProperties AwfulPostFetchedProperties = {
};

@implementation AwfulPostID
@end

@implementation _AwfulPost

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulPost" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulPost";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulPost" inManagedObjectContext:moc_];
}

- (AwfulPostID*)objectID {
	return (AwfulPostID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"beenSeenValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"beenSeen"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"editableValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"editable"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"threadIndexValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"threadIndex"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"threadPageValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"threadPage"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic beenSeen;



- (BOOL)beenSeenValue {
	NSNumber *result = [self beenSeen];
	return [result boolValue];
}

- (void)setBeenSeenValue:(BOOL)value_ {
	[self setBeenSeen:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveBeenSeenValue {
	NSNumber *result = [self primitiveBeenSeen];
	return [result boolValue];
}

- (void)setPrimitiveBeenSeenValue:(BOOL)value_ {
	[self setPrimitiveBeenSeen:[NSNumber numberWithBool:value_]];
}





@dynamic editable;



- (BOOL)editableValue {
	NSNumber *result = [self editable];
	return [result boolValue];
}

- (void)setEditableValue:(BOOL)value_ {
	[self setEditable:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveEditableValue {
	NSNumber *result = [self primitiveEditable];
	return [result boolValue];
}

- (void)setPrimitiveEditableValue:(BOOL)value_ {
	[self setPrimitiveEditable:[NSNumber numberWithBool:value_]];
}





@dynamic innerHTML;






@dynamic postDate;






@dynamic postID;






@dynamic threadIndex;



- (int32_t)threadIndexValue {
	NSNumber *result = [self threadIndex];
	return [result intValue];
}

- (void)setThreadIndexValue:(int32_t)value_ {
	[self setThreadIndex:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveThreadIndexValue {
	NSNumber *result = [self primitiveThreadIndex];
	return [result intValue];
}

- (void)setPrimitiveThreadIndexValue:(int32_t)value_ {
	[self setPrimitiveThreadIndex:[NSNumber numberWithInt:value_]];
}





@dynamic threadPage;



- (int32_t)threadPageValue {
	NSNumber *result = [self threadPage];
	return [result intValue];
}

- (void)setThreadPageValue:(int32_t)value_ {
	[self setThreadPage:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveThreadPageValue {
	NSNumber *result = [self primitiveThreadPage];
	return [result intValue];
}

- (void)setPrimitiveThreadPageValue:(int32_t)value_ {
	[self setPrimitiveThreadPage:[NSNumber numberWithInt:value_]];
}





@dynamic author;

	

@dynamic thread;

	






@end
