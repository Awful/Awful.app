// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulThreadTag.m instead.

#import "_AwfulThreadTag.h"

const struct AwfulThreadTagAttributes AwfulThreadTagAttributes = {
	.alt = @"alt",
	.filename = @"filename",
};

const struct AwfulThreadTagRelationships AwfulThreadTagRelationships = {
	.forum = @"forum",
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
	

	return keyPaths;
}




@dynamic alt;






@dynamic filename;






@dynamic forum;

	
- (NSMutableSet*)forumSet {
	[self willAccessValueForKey:@"forum"];
  
	NSMutableSet *result = (NSMutableSet*)[self mutableSetValueForKey:@"forum"];
  
	[self didAccessValueForKey:@"forum"];
	return result;
}
	






@end
