// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulEmoticon.m instead.

#import "_AwfulEmoticon.h"

const struct AwfulEmoticonAttributes AwfulEmoticonAttributes = {
	.cachedString = @"cachedString",
	.code = @"code",
	.desc = @"desc",
	.urlString = @"urlString",
	.usageCount = @"usageCount",
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
	
	if ([key isEqualToString:@"usageCountValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"usageCount"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic cachedString;






@dynamic code;






@dynamic desc;






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





@dynamic group;

	






@end
