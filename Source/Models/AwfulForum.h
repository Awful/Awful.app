//
//  AwfulForum.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "_AwfulForum.h"
#import "AwfulParsing.h"

@interface AwfulForum : _AwfulForum {}

+ (NSArray *)updateCategoriesAndForums:(ForumHierarchyParsedInfo *)info;

+ (NSArray *)updateCategoriesAndForumsWithJSON:(NSArray *)json;

@end
