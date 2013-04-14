//
//  AwfulPost.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "_AwfulPost.h"
@class PageParsedInfo;

@interface AwfulPost : _AwfulPost

@property (readonly, nonatomic) BOOL beenSeen;
@property (readonly, nonatomic) NSInteger page;
@property (readonly, nonatomic) NSInteger singleUserPage;

+ (NSArray *)postsCreatedOrUpdatedFromPageInfo:(PageParsedInfo *)pageInfo;
+ (NSArray *)postsCreatedOrUpdatedFromJSON:(NSDictionary *)json
                              singleUserID:(NSString *)singleUserID;

@end
