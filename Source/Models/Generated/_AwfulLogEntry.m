// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to AwfulLogEntry.m instead.

#import "_AwfulLogEntry.h"

const struct AwfulLogEntryAttributes AwfulLogEntryAttributes = {
	.category = @"category",
	.date = @"date",
	.fromClass = @"fromClass",
	.message = @"message",
};

const struct AwfulLogEntryRelationships AwfulLogEntryRelationships = {
};

const struct AwfulLogEntryFetchedProperties AwfulLogEntryFetchedProperties = {
};

@implementation AwfulLogEntryID
@end

@implementation _AwfulLogEntry

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"AwfulLogEntry" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"AwfulLogEntry";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"AwfulLogEntry" inManagedObjectContext:moc_];
}

- (AwfulLogEntryID*)objectID {
	return (AwfulLogEntryID*)[super objectID];
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	

	return keyPaths;
}




@dynamic category;






@dynamic date;






@dynamic fromClass;






@dynamic message;











@end
