// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulLeper.m instead.

#import "_AwfulLeper.h"

const struct AwfulLeperAttributes AwfulLeperAttributes = {
	.banID = @"banID",
	.banType = @"banType",
	.date = @"date",
	.reason = @"reason",
};

const struct AwfulLeperRelationships AwfulLeperRelationships = {
	.admin = @"admin",
	.jerk = @"jerk",
	.mod = @"mod",
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






@dynamic reason;






@dynamic admin;

	

@dynamic jerk;

	

@dynamic mod;

	






@end
