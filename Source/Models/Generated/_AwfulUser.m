// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulUser.m instead.

#import "_AwfulUser.h"

const struct AwfulUserAttributes AwfulUserAttributes = {
	.postsPerPage = @"postsPerPage",
	.userID = @"userID",
	.userName = @"userName",
};

const struct AwfulUserRelationships AwfulUserRelationships = {
};

const struct AwfulUserFetchedProperties AwfulUserFetchedProperties = {
};

@implementation AwfulUserID
@end

@implementation _AwfulUser

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulUser" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulUser";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulUser" inManagedObjectContext:moc_];
}

- (AwfulUserID*)objectID {
	return (AwfulUserID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"postsPerPageValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"postsPerPage"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic postsPerPage;



- (int32_t)postsPerPageValue {
	NSNumber *result = [self postsPerPage];
	return [result intValue];
}

- (void)setPostsPerPageValue:(int32_t)value_ {
	[self setPostsPerPage:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitivePostsPerPageValue {
	NSNumber *result = [self primitivePostsPerPage];
	return [result intValue];
}

- (void)setPrimitivePostsPerPageValue:(int32_t)value_ {
	[self setPrimitivePostsPerPage:[NSNumber numberWithInt:value_]];
}





@dynamic userID;






@dynamic userName;











@end
