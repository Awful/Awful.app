// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulEmoticon.m instead.

#import "_AwfulEmoticon.h"

const struct AwfulEmoticonAttributes AwfulEmoticonAttributes = {
	.cachedPath = @"cachedPath",
	.code = @"code",
	.desc = @"desc",
	.height = @"height",
	.urlString = @"urlString",
	.usageCount = @"usageCount",
	.width = @"width",
};

const struct AwfulEmoticonRelationships AwfulEmoticonRelationships = {
	.group = @"group",
};

const struct AwfulEmoticonFetchedProperties AwfulEmoticonFetchedProperties = {
};

@implementation AwfulEmoticonID
@end

@implementation _AwfulEmoticon

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulEmoticon" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulEmoticon";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulEmoticon" inManagedObjectContext:moc_];
}

- (AwfulEmoticonID*)objectID {
	return (AwfulEmoticonID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"heightValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"height"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"usageCountValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"usageCount"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"widthValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"width"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic cachedPath;






@dynamic code;






@dynamic desc;






@dynamic height;



- (int32_t)heightValue {
	NSNumber *result = [self height];
	return [result intValue];
}

- (void)setHeightValue:(int32_t)value_ {
	[self setHeight:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveHeightValue {
	NSNumber *result = [self primitiveHeight];
	return [result intValue];
}

- (void)setPrimitiveHeightValue:(int32_t)value_ {
	[self setPrimitiveHeight:[NSNumber numberWithInt:value_]];
}





@dynamic urlString;






@dynamic usageCount;



- (int32_t)usageCountValue {
	NSNumber *result = [self usageCount];
	return [result intValue];
}

- (void)setUsageCountValue:(int32_t)value_ {
	[self setUsageCount:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveUsageCountValue {
	NSNumber *result = [self primitiveUsageCount];
	return [result intValue];
}

- (void)setPrimitiveUsageCountValue:(int32_t)value_ {
	[self setPrimitiveUsageCount:[NSNumber numberWithInt:value_]];
}





@dynamic width;



- (int32_t)widthValue {
	NSNumber *result = [self width];
	return [result intValue];
}

- (void)setWidthValue:(int32_t)value_ {
	[self setWidth:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveWidthValue {
	NSNumber *result = [self primitiveWidth];
	return [result intValue];
}

- (void)setPrimitiveWidthValue:(int32_t)value_ {
	[self setPrimitiveWidth:[NSNumber numberWithInt:value_]];
}





@dynamic group;

	






@end
