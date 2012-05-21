// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulEmote.m instead.

#import "_AwfulEmote.h"

const struct AwfulEmoteAttributes AwfulEmoteAttributes = {
	.code = @"code",
	.desc = @"desc",
};

const struct AwfulEmoteRelationships AwfulEmoteRelationships = {
};

const struct AwfulEmoteFetchedProperties AwfulEmoteFetchedProperties = {
};

@implementation AwfulEmoteID
@end

@implementation _AwfulEmote

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulEmote" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulEmote";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulEmote" inManagedObjectContext:moc_];
}

- (AwfulEmoteID*)objectID {
	return (AwfulEmoteID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	

	return keyPaths;
}




@dynamic code;






@dynamic desc;











@end
