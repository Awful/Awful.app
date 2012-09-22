// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulCategory.m instead.

#import "_AwfulCategory.h"

const struct AwfulCategoryAttributes AwfulCategoryAttributes = {
	.categoryID = @"categoryID",
	.index = @"index",
	.name = @"name",
};

const struct AwfulCategoryRelationships AwfulCategoryRelationships = {
	.forums = @"forums",
};

const struct AwfulCategoryFetchedProperties AwfulCategoryFetchedProperties = {
};

@implementation AwfulCategoryID
@end

@implementation _AwfulCategory

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulCategory" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulCategory";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulCategory" inManagedObjectContext:moc_];
}

- (AwfulCategoryID*)objectID {
	return (AwfulCategoryID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"indexValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"index"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic categoryID;






@dynamic index;



- (int32_t)indexValue {
	NSNumber *result = [self index];
	return [result intValue];
}

- (void)setIndexValue:(int32_t)value_ {
	[self setIndex:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveIndexValue {
	NSNumber *result = [self primitiveIndex];
	return [result intValue];
}

- (void)setPrimitiveIndexValue:(int32_t)value_ {
	[self setPrimitiveIndex:[NSNumber numberWithInt:value_]];
}





@dynamic name;






@dynamic forums;

	
- (NSMutableSet*)forumsSet {
	[self willAccessValueForKey:@"forums"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"forums"];
  
	[self didAccessValueForKey:@"forums"];
	return result;
}
	






@end
