// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulSingleUserThreadInfo.m instead.

#import "_AwfulSingleUserThreadInfo.h"

const struct AwfulSingleUserThreadInfoAttributes AwfulSingleUserThreadInfoAttributes = {
	.numberOfPages = @"numberOfPages",
};

const struct AwfulSingleUserThreadInfoRelationships AwfulSingleUserThreadInfoRelationships = {
	.author = @"author",
	.thread = @"thread",
};

const struct AwfulSingleUserThreadInfoFetchedProperties AwfulSingleUserThreadInfoFetchedProperties = {
};

@implementation AwfulSingleUserThreadInfoID
@end

@implementation _AwfulSingleUserThreadInfo

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulSingleUserThreadInfo" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulSingleUserThreadInfo";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulSingleUserThreadInfo" inManagedObjectContext:moc_];
}

- (AwfulSingleUserThreadInfoID*)objectID {
	return (AwfulSingleUserThreadInfoID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"numberOfPagesValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"numberOfPages"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic numberOfPages;



- (int32_t)numberOfPagesValue {
	NSNumber *result = [self numberOfPages];
	return [result intValue];
}

- (void)setNumberOfPagesValue:(int32_t)value_ {
	[self setNumberOfPages:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveNumberOfPagesValue {
	NSNumber *result = [self primitiveNumberOfPages];
	return [result intValue];
}

- (void)setPrimitiveNumberOfPagesValue:(int32_t)value_ {
	[self setPrimitiveNumberOfPages:[NSNumber numberWithInt:value_]];
}





@dynamic author;

	

@dynamic thread;

	






@end
