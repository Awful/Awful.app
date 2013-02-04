// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulLeper.m instead.

#import "_AwfulLeper.h"

const struct AwfulLeperAttributes AwfulLeperAttributes = {
	.banID = @"banID",
	.banType = @"banType",
	.date = @"date",
	.postID = @"postID",
	.reason = @"reason",
};

const struct AwfulLeperRelationships AwfulLeperRelationships = {
	.admin = @"admin",
	.jerk = @"jerk",
	.mod = @"mod",
	.post = @"post",
};

const struct AwfulLeperFetchedProperties AwfulLeperFetchedProperties = {
};

@implementation AwfulLeperID
@end

@implementation _AwfulLeper

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulLeper" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulLeper";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulLeper" inManagedObjectContext:moc_];
}

- (AwfulLeperID*)objectID {
	return (AwfulLeperID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"banTypeValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"banType"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}
	if ([key isEqualToString:@"postIDValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"postID"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic banID;






@dynamic banType;



- (int16_t)banTypeValue {
	NSNumber *result = [self banType];
	return [result shortValue];
}

- (void)setBanTypeValue:(int16_t)value_ {
	[self setBanType:[NSNumber numberWithShort:value_]];
}

- (int16_t)primitiveBanTypeValue {
	NSNumber *result = [self primitiveBanType];
	return [result shortValue];
}

- (void)setPrimitiveBanTypeValue:(int16_t)value_ {
	[self setPrimitiveBanType:[NSNumber numberWithShort:value_]];
}





@dynamic date;






@dynamic postID;



- (int32_t)postIDValue {
	NSNumber *result = [self postID];
	return [result intValue];
}

- (void)setPostIDValue:(int32_t)value_ {
	[self setPostID:[NSNumber numberWithInt:value_]];
}

- (int32_t)primitivePostIDValue {
	NSNumber *result = [self primitivePostID];
	return [result intValue];
}

- (void)setPrimitivePostIDValue:(int32_t)value_ {
	[self setPrimitivePostID:[NSNumber numberWithInt:value_]];
}





@dynamic reason;






@dynamic admin;

	

@dynamic jerk;

	

@dynamic mod;

	

@dynamic post;

	






@end
