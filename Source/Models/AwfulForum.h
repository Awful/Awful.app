//
//  AwfulForum.h
//  Awful
//
//  Created by Nolan Waite on 12-05-17.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "_AwfulForum.h"
#import "AwfulParsing.h"

@interface AwfulForum : _AwfulForum {}

+ (NSArray *)updateCategoriesAndForums:(ForumHierarchyParsedInfo *)info;

+ (NSArray *)updateCategoriesAndForumsWithJSON:(NSArray *)json;

@end
