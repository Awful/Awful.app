// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulFavorite.m instead.

#import "_AwfulFavorite.h"

const struct AwfulFavoriteAttributes AwfulFavoriteAttributes = {
	.displayOrder = @"displayOrder",
};

const struct AwfulFavoriteRelationships AwfulFavoriteRelationships = {
	.forum = @"forum",
};

const struct AwfulFavoriteFetchedProperties AwfulFavoriteFetchedProperties = {
};

@implementation AwfulFavoriteID
@end

@implementation _AwfulFavorite

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Favorite";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Favorite" inManagedObjectContext:moc_];
}

- (AwfulFavoriteID*)objectID {
	return (AwfulFavoriteID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"displayOrderValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"displayOrder"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic displayOrder;



- (int32_t)displayOrderValue {
	NSNumber *result = [self displayOrder];
	return [result intValue];
}

- (void)setDisplayOrderValue:(int32_t)value_ {
	[self setDisplayOrder:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveDisplayOrderValue {
	NSNumber *result = [self primitiveDisplayOrder];
	return [result intValue];
}

- (void)setPrimitiveDisplayOrderValue:(int32_t)value_ {
	[self setPrimitiveDisplayOrder:[NSNumber numberWithInt:value_]];
}





@dynamic forum;

	






@end
