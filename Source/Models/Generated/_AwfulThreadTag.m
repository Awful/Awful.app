// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulThreadTag.m instead.

#import "_AwfulThreadTag.h"

const struct AwfulThreadTagAttributes AwfulThreadTagAttributes = {
	.alt = @"alt",
	.filename = @"filename",
	.tagID = @"tagID",
};

const struct AwfulThreadTagRelationships AwfulThreadTagRelationships = {
	.forums = @"forums",
	.threads = @"threads",
};

const struct AwfulThreadTagFetchedProperties AwfulThreadTagFetchedProperties = {
};

@implementation AwfulThreadTagID
@end

@implementation _AwfulThreadTag

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulThreadTag" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulThreadTag";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulThreadTag" inManagedObjectContext:moc_];
}

- (AwfulThreadTagID*)objectID {
	return (AwfulThreadTagID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"tagIDValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"tagID"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
	}

	return keyPaths;
}




@dynamic alt;






@dynamic filename;






@dynamic tagID;



- (int16_t)tagIDValue {
	NSNumber *result = [self tagID];
	return [result shortValue];
}

- (void)setTagIDValue:(int16_t)value_ {
	[self setTagID:[NSNumber numberWithShort:value_]];
}

- (int16_t)primitiveTagIDValue {
	NSNumber *result = [self primitiveTagID];
	return [result shortValue];
}

- (void)setPrimitiveTagIDValue:(int16_t)value_ {
	[self setPrimitiveTagID:[NSNumber numberWithShort:value_]];
}





@dynamic forums;

	
- (NSMutableSet*)forumsSet {
	[self willAccessValueForKey:@"forums"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"forums"];
  
	[self didAccessValueForKey:@"forums"];
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
