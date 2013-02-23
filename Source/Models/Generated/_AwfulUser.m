// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulUser.m instead.

#import "_AwfulUser.h"

const struct AwfulUserAttributes AwfulUserAttributes = {
	.aboutMe = @"aboutMe",
	.administrator = @"administrator",
	.aimName = @"aimName",
	.customTitle = @"customTitle",
	.gender = @"gender",
	.homepageURL = @"homepageURL",
	.icqName = @"icqName",
	.interests = @"interests",
	.lastPost = @"lastPost",
	.location = @"location",
	.moderator = @"moderator",
	.occupation = @"occupation",
	.postCount = @"postCount",
	.postRate = @"postRate",
	.profilePictureURL = @"profilePictureURL",
	.regdate = @"regdate",
	.userID = @"userID",
	.username = @"username",
	.yahooName = @"yahooName",
};

const struct AwfulUserRelationships AwfulUserRelationships = {
	.editedPosts = @"editedPosts",
	.posts = @"posts",
	.receivedPrivateMessages = @"receivedPrivateMessages",
	.sentPrivateMessages = @"sentPrivateMessages",
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
	if ([key isEqualToString:@"postCountValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"postCount"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic aboutMe;






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





@dynamic aimName;






@dynamic customTitle;






@dynamic gender;






@dynamic homepageURL;






@dynamic icqName;






@dynamic interests;






@dynamic lastPost;






@dynamic location;






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





@dynamic occupation;






@dynamic postCount;



- (int32_t)postCountValue {
	NSNumber *result = [self postCount];
	return [result intValue];
}

- (void)setPostCountValue:(int32_t)value_ {
	[self setPostCount:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitivePostCountValue {
	NSNumber *result = [self primitivePostCount];
	return [result intValue];
}

- (void)setPrimitivePostCountValue:(int32_t)value_ {
	[self setPrimitivePostCount:[NSNumber numberWithInt:value_]];
}





@dynamic postRate;






@dynamic profilePictureURL;






@dynamic regdate;






@dynamic userID;






@dynamic username;






@dynamic yahooName;






@dynamic editedPosts;

	
- (NSMutableSet*)editedPostsSet {
	[self willAccessValueForKey:@"editedPosts"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"editedPosts"];
  
	[self didAccessValueForKey:@"editedPosts"];
	return result;
}
	

@dynamic posts;

	
- (NSMutableSet*)postsSet {
	[self willAccessValueForKey:@"posts"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"posts"];
  
	[self didAccessValueForKey:@"posts"];
	return result;
}
	

@dynamic receivedPrivateMessages;

	

@dynamic sentPrivateMessages;

	

@dynamic threads;

	
- (NSMutableSet*)threadsSet {
	[self willAccessValueForKey:@"threads"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"threads"];
  
	[self didAccessValueForKey:@"threads"];
	return result;
}
	






@end
