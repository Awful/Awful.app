// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulForum.m instead.

#import "_AwfulForum.h"

const struct AwfulForumAttributes AwfulForumAttributes = {
	.desc = @"desc",
	.expanded = @"expanded",
	.forumID = @"forumID",
	.index = @"index",
	.isCategory = @"isCategory",
	.name = @"name",
};

const struct AwfulForumRelationships AwfulForumRelationships = {
	.category = @"category",
	.children = @"children",
	.favorite = @"favorite",
	.parentForum = @"parentForum",
	.threadTags = @"threadTags",
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
	if ([key isEqualToString:@"indexValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"index"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"isCategoryValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"isCategory"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic desc;






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





@dynamic isCategory;



- (BOOL)isCategoryValue {
	NSNumber *result = [self isCategory];
	return [result boolValue];
}

- (void)setIsCategoryValue:(BOOL)value_ {
	[self setIsCategory:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveIsCategoryValue {
	NSNumber *result = [self primitiveIsCategory];
	return [result boolValue];
}

- (void)setPrimitiveIsCategoryValue:(BOOL)value_ {
	[self setPrimitiveIsCategory:[NSNumber numberWithBool:value_]];
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
	

@dynamic favorite;

	

@dynamic parentForum;

	

@dynamic threadTags;

	
- (NSMutableSet*)threadTagsSet {
	[self willAccessValueForKey:@"threadTags"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"threadTags"];
  
	[self didAccessValueForKey:@"threadTags"];
	return result;
}
	

@dynamic threads;

	
- (NSMutableSet*)threadsSet {
	[self willAccessValueForKey:@"threads"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"threads"];
  
	[self didAccessValueForKey:@"threads"];
	return result;
}
	






@end
