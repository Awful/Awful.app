// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulForum.m instead.

#import "_AwfulForum.h"

const struct AwfulForumAttributes AwfulForumAttributes = {
	.expanded = @"expanded",
	.favoriteIndex = @"favoriteIndex",
	.forumID = @"forumID",
	.index = @"index",
	.isFavorite = @"isFavorite",
	.name = @"name",
};

const struct AwfulForumRelationships AwfulForumRelationships = {
	.category = @"category",
	.children = @"children",
	.parentForum = @"parentForum",
	.threads = @"threads",
};

const struct AwfulForumFetchedProperties AwfulForumFetchedProperties = {
};

@implementation AwfulForumID
@end

@implementation _AwfulForum

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulForum" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulForum";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulForum" inManagedObjectContext:moc_];
}

- (AwfulForumID*)objectID {
	return (AwfulForumID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"expandedValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"expanded"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"favoriteIndexValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"favoriteIndex"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"indexValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"index"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"isFavoriteValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"isFavorite"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic expanded;



- (BOOL)expandedValue {
	NSNumber *result = [self expanded];
	return [result boolValue];
}

- (void)setExpandedValue:(BOOL)value_ {
	[self setExpanded:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveExpandedValue {
	NSNumber *result = [self primitiveExpanded];
	return [result boolValue];
}

- (void)setPrimitiveExpandedValue:(BOOL)value_ {
	[self setPrimitiveExpanded:[NSNumber numberWithBool:value_]];
}





@dynamic favoriteIndex;



- (int32_t)favoriteIndexValue {
	NSNumber *result = [self favoriteIndex];
	return [result intValue];
}

- (void)setFavoriteIndexValue:(int32_t)value_ {
	[self setFavoriteIndex:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveFavoriteIndexValue {
	NSNumber *result = [self primitiveFavoriteIndex];
	return [result intValue];
}

- (void)setPrimitiveFavoriteIndexValue:(int32_t)value_ {
	[self setPrimitiveFavoriteIndex:[NSNumber numberWithInt:value_]];
}





@dynamic forumID;






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





@dynamic isFavorite;



- (BOOL)isFavoriteValue {
	NSNumber *result = [self isFavorite];
	return [result boolValue];
}

- (void)setIsFavoriteValue:(BOOL)value_ {
	[self setIsFavorite:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveIsFavoriteValue {
	NSNumber *result = [self primitiveIsFavorite];
	return [result boolValue];
}

- (void)setPrimitiveIsFavoriteValue:(BOOL)value_ {
	[self setPrimitiveIsFavorite:[NSNumber numberWithBool:value_]];
}





@dynamic name;






@dynamic category;

	

@dynamic children;

	
- (NSMutableOrderedSet*)childrenSet {
	[self willAccessValueForKey:@"children"];
  
	NSMutableOrderedSet *result = (NSMutableOrderedSet*)[self mutableOrderedSetValueForKey:@"children"];
  
	[self didAccessValueForKey:@"children"];
	return result;
}
	

@dynamic parentForum;

	

@dynamic threads;

	
- (NSMutableSet*)threadsSet {
	[self willAccessValueForKey:@"threads"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"threads"];
  
	[self didAccessValueForKey:@"threads"];
	return result;
}
	






@end
