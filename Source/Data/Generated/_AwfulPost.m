// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulPost.m instead.

#import "_AwfulPost.h"

const struct AwfulPostAttributes AwfulPostAttributes = {
	.attachmentID = @"attachmentID",
	.editDate = @"editDate",
	.editable = @"editable",
	.innerHTML = @"innerHTML",
	.postDate = @"postDate",
	.postID = @"postID",
	.singleUserIndex = @"singleUserIndex",
	.threadIndex = @"threadIndex",
};

const struct AwfulPostRelationships AwfulPostRelationships = {
	.author = @"author",
	.editor = @"editor",
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
	
	if ([key isEqualToString:@"editableValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"editable"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"singleUserIndexValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"singleUserIndex"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"threadIndexValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"threadIndex"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic attachmentID;






@dynamic editDate;






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






@dynamic singleUserIndex;



- (int32_t)singleUserIndexValue {
	NSNumber *result = [self singleUserIndex];
	return [result intValue];
}

- (void)setSingleUserIndexValue:(int32_t)value_ {
	[self setSingleUserIndex:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveSingleUserIndexValue {
	NSNumber *result = [self primitiveSingleUserIndex];
	return [result intValue];
}

- (void)setPrimitiveSingleUserIndexValue:(int32_t)value_ {
	[self setPrimitiveSingleUserIndex:[NSNumber numberWithInt:value_]];
}





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





@dynamic author;

	

@dynamic editor;

	

@dynamic thread;

	






@end
