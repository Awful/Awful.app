//
//  AwfulPost.h
//  Awful
//
//  Created by Nolan Waite on 12-10-26.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "_AwfulPost.h"
@class PageParsedInfo;

@interface AwfulPost : _AwfulPost

@property (readonly, nonatomic) BOOL beenSeen;

+ (NSArray *)postsCreatedOrUpdatedFromPageInfo:(PageParsedInfo *)pageInfo;

+ (NSArray *)postsCreatedOrUpdatedFromJSON:(NSDictionary *)json;

- (BOOL)editableByUserWithID:(NSString *)userID;

@end
