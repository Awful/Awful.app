// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulCachedImage.m instead.

#import "_AwfulCachedImage.h"

const struct AwfulCachedImageAttributes AwfulCachedImageAttributes = {
	.cacheDate = @"cacheDate",
	.imageData = @"imageData",
	.urlString = @"urlString",
};

const struct AwfulCachedImageRelationships AwfulCachedImageRelationships = {
};

const struct AwfulCachedImageFetchedProperties AwfulCachedImageFetchedProperties = {
};

@implementation AwfulCachedImageID
@end

@implementation _AwfulCachedImage

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulCachedImage" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulCachedImage";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulCachedImage" inManagedObjectContext:moc_];
}

- (AwfulCachedImageID*)objectID {
	return (AwfulCachedImageID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	

	return keyPaths;
}




@dynamic cacheDate;






@dynamic imageData;






@dynamic urlString;











@end
