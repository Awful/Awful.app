// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulUser.m instead.

#import "_AwfulUser.h"

const struct AwfulUserAttributes AwfulUserAttributes = {
	.administrator = @"administrator",
	.avatarURL = @"avatarURL",
	.customTitle = @"customTitle",
	.moderator = @"moderator",
	.regdate = @"regdate",
	.userID = @"userID",
	.username = @"username",
};

const struct AwfulUserRelationships AwfulUserRelationships = {
	.posts = @"posts",
	.threads = @"threads",
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

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"administratorValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"administrator"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"moderatorValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"moderator"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic administrator;



- (BOOL)administratorValue {
	NSNumber *result = [self administrator];
	return [result boolValue];
}

- (void)setAdministratorValue:(BOOL)value_ {
	[self setAdministrator:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveAdministratorValue {
	NSNumber *result = [self primitiveAdministrator];
	return [result boolValue];
}

- (void)setPrimitiveAdministratorValue:(BOOL)value_ {
	[self setPrimitiveAdministrator:[NSNumber numberWithBool:value_]];
}





@dynamic avatarURL;






@dynamic customTitle;






@dynamic moderator;



- (BOOL)moderatorValue {
	NSNumber *result = [self moderator];
	return [result boolValue];
}

- (void)setModeratorValue:(BOOL)value_ {
	[self setModerator:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveModeratorValue {
	NSNumber *result = [self primitiveModerator];
	return [result boolValue];
}

- (void)setPrimitiveModeratorValue:(BOOL)value_ {
	[self setPrimitiveModerator:[NSNumber numberWithBool:value_]];
}





@dynamic regdate;






@dynamic userID;






@dynamic username;






@dynamic posts;

	
- (NSMutableSet*)postsSet {
	[self willAccessValueForKey:@"posts"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"posts"];
  
	[self didAccessValueForKey:@"posts"];
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
