// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulEmoticonGroup.m instead.

#import "_AwfulEmoticonGroup.h"

const struct AwfulEmoticonGroupAttributes AwfulEmoticonGroupAttributes = {
	.desc = @"desc",
};

const struct AwfulEmoticonGroupRelationships AwfulEmoticonGroupRelationships = {
	.emoticons = @"emoticons",
};

const struct AwfulEmoticonGroupFetchedProperties AwfulEmoticonGroupFetchedProperties = {
};

@implementation AwfulEmoticonGroupID
@end

@implementation _AwfulEmoticonGroup

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulEmoticonGroup" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulEmoticonGroup";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulEmoticonGroup" inManagedObjectContext:moc_];
}

- (AwfulEmoticonGroupID*)objectID {
	return (AwfulEmoticonGroupID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	

	return keyPaths;
}




@dynamic desc;






@dynamic emoticons;

	
- (NSMutableSet*)emoticonsSet {
	[self willAccessValueForKey:@"emoticons"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"emoticons"];
  
	[self didAccessValueForKey:@"emoticons"];
	return result;
}
	






@end
