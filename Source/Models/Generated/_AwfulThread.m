// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulThread.m instead.

#import "_AwfulThread.h"

const struct AwfulThreadAttributes AwfulThreadAttributes = {
	.authorName = @"authorName",
	.hideFromList = @"hideFromList",
	.isBookmarked = @"isBookmarked",
	.isClosed = @"isClosed",
	.isLocked = @"isLocked",
	.isSticky = @"isSticky",
	.lastPostAuthorName = @"lastPostAuthorName",
	.lastPostDate = @"lastPostDate",
	.seen = @"seen",
	.starCategory = @"starCategory",
	.stickyIndex = @"stickyIndex",
	.threadID = @"threadID",
	.threadIconImageURL = @"threadIconImageURL",
	.threadIconImageURL2 = @"threadIconImageURL2",
	.threadRating = @"threadRating",
	.threadVotes = @"threadVotes",
	.title = @"title",
	.totalReplies = @"totalReplies",
	.totalUnreadPosts = @"totalUnreadPosts",
};

const struct AwfulThreadRelationships AwfulThreadRelationships = {
	.forum = @"forum",
};

const struct AwfulThreadFetchedProperties AwfulThreadFetchedProperties = {
};

@implementation AwfulThreadID
@end

@implementation _AwfulThread

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulThread" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulThread";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulThread" inManagedObjectContext:moc_];
}

- (AwfulThreadID*)objectID {
	return (AwfulThreadID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"hideFromListValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"hideFromList"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"isBookmarkedValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"isBookmarked"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"isClosedValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"isClosed"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"isLockedValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"isLocked"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"isStickyValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"isSticky"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"seenValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"seen"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"starCategoryValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"starCategory"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"stickyIndexValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"stickyIndex"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"threadVotesValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"threadVotes"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"totalRepliesValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"totalReplies"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}
	if ([key isEqualToString:@"totalUnreadPostsValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"totalUnreadPosts"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic authorName;






@dynamic hideFromList;



- (BOOL)hideFromListValue {
	NSNumber *result = [self hideFromList];
	return [result boolValue];
}

- (void)setHideFromListValue:(BOOL)value_ {
	[self setHideFromList:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveHideFromListValue {
	NSNumber *result = [self primitiveHideFromList];
	return [result boolValue];
}

- (void)setPrimitiveHideFromListValue:(BOOL)value_ {
	[self setPrimitiveHideFromList:[NSNumber numberWithBool:value_]];
}





@dynamic isBookmarked;



- (BOOL)isBookmarkedValue {
	NSNumber *result = [self isBookmarked];
	return [result boolValue];
}

- (void)setIsBookmarkedValue:(BOOL)value_ {
	[self setIsBookmarked:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveIsBookmarkedValue {
	NSNumber *result = [self primitiveIsBookmarked];
	return [result boolValue];
}

- (void)setPrimitiveIsBookmarkedValue:(BOOL)value_ {
	[self setPrimitiveIsBookmarked:[NSNumber numberWithBool:value_]];
}





@dynamic isClosed;



- (BOOL)isClosedValue {
	NSNumber *result = [self isClosed];
	return [result boolValue];
}

- (void)setIsClosedValue:(BOOL)value_ {
	[self setIsClosed:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveIsClosedValue {
	NSNumber *result = [self primitiveIsClosed];
	return [result boolValue];
}

- (void)setPrimitiveIsClosedValue:(BOOL)value_ {
	[self setPrimitiveIsClosed:[NSNumber numberWithBool:value_]];
}





@dynamic isLocked;



- (BOOL)isLockedValue {
	NSNumber *result = [self isLocked];
	return [result boolValue];
}

- (void)setIsLockedValue:(BOOL)value_ {
	[self setIsLocked:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveIsLockedValue {
	NSNumber *result = [self primitiveIsLocked];
	return [result boolValue];
}

- (void)setPrimitiveIsLockedValue:(BOOL)value_ {
	[self setPrimitiveIsLocked:[NSNumber numberWithBool:value_]];
}





@dynamic isSticky;



- (BOOL)isStickyValue {
	NSNumber *result = [self isSticky];
	return [result boolValue];
}

- (void)setIsStickyValue:(BOOL)value_ {
	[self setIsSticky:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveIsStickyValue {
	NSNumber *result = [self primitiveIsSticky];
	return [result boolValue];
}

- (void)setPrimitiveIsStickyValue:(BOOL)value_ {
	[self setPrimitiveIsSticky:[NSNumber numberWithBool:value_]];
}





@dynamic lastPostAuthorName;






@dynamic lastPostDate;






@dynamic seen;



- (BOOL)seenValue {
	NSNumber *result = [self seen];
	return [result boolValue];
}

- (void)setSeenValue:(BOOL)value_ {
	[self setSeen:[NSNumber numberWithBool:value_]];
}

- (BOOL)primitiveSeenValue {
	NSNumber *result = [self primitiveSeen];
	return [result boolValue];
}

- (void)setPrimitiveSeenValue:(BOOL)value_ {
	[self setPrimitiveSeen:[NSNumber numberWithBool:value_]];
}





@dynamic starCategory;



- (int16_t)starCategoryValue {
	NSNumber *result = [self starCategory];
	return [result shortValue];
}

- (void)setStarCategoryValue:(int16_t)value_ {
	[self setStarCategory:[NSNumber numberWithShort:value_]];
}

- (int16_t)primitiveStarCategoryValue {
	NSNumber *result = [self primitiveStarCategory];
	return [result shortValue];
}

- (void)setPrimitiveStarCategoryValue:(int16_t)value_ {
	[self setPrimitiveStarCategory:[NSNumber numberWithShort:value_]];
}





@dynamic stickyIndex;



- (int32_t)stickyIndexValue {
	NSNumber *result = [self stickyIndex];
	return [result intValue];
}

- (void)setStickyIndexValue:(int32_t)value_ {
	[self setStickyIndex:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveStickyIndexValue {
	NSNumber *result = [self primitiveStickyIndex];
	return [result intValue];
}

- (void)setPrimitiveStickyIndexValue:(int32_t)value_ {
	[self setPrimitiveStickyIndex:[NSNumber numberWithInt:value_]];
}





@dynamic threadID;






@dynamic threadIconImageURL;






@dynamic threadIconImageURL2;






@dynamic threadRating;






@dynamic threadVotes;



- (int16_t)threadVotesValue {
	NSNumber *result = [self threadVotes];
	return [result shortValue];
}

- (void)setThreadVotesValue:(int16_t)value_ {
	[self setThreadVotes:[NSNumber numberWithShort:value_]];
}

- (int16_t)primitiveThreadVotesValue {
	NSNumber *result = [self primitiveThreadVotes];
	return [result shortValue];
}

- (void)setPrimitiveThreadVotesValue:(int16_t)value_ {
	[self setPrimitiveThreadVotes:[NSNumber numberWithShort:value_]];
}





@dynamic title;






@dynamic totalReplies;



- (int32_t)totalRepliesValue {
	NSNumber *result = [self totalReplies];
	return [result intValue];
}

- (void)setTotalRepliesValue:(int32_t)value_ {
	[self setTotalReplies:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveTotalRepliesValue {
	NSNumber *result = [self primitiveTotalReplies];
	return [result intValue];
}

- (void)setPrimitiveTotalRepliesValue:(int32_t)value_ {
	[self setPrimitiveTotalReplies:[NSNumber numberWithInt:value_]];
}





@dynamic totalUnreadPosts;



- (int32_t)totalUnreadPostsValue {
	NSNumber *result = [self totalUnreadPosts];
	return [result intValue];
}

- (void)setTotalUnreadPostsValue:(int32_t)value_ {
	[self setTotalUnreadPosts:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitiveTotalUnreadPostsValue {
	NSNumber *result = [self primitiveTotalUnreadPosts];
	return [result intValue];
}

- (void)setPrimitiveTotalUnreadPostsValue:(int32_t)value_ {
	[self setPrimitiveTotalUnreadPosts:[NSNumber numberWithInt:value_]];
}





@dynamic forum;

	






@end
