//
//  ForumTests.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ParsingTests.h"

@interface ForumTests : ParsingTests

@end


@implementation ForumTests

+ (NSString *)fixtureFilename
{
    return @"forumdisplay.html";
}

- (void)testCategoryAndForumHierarchy
{
    ForumHierarchyParsedInfo *info = [[ForumHierarchyParsedInfo alloc] initWithHTMLData:self.fixture];
    
    NSArray *categoryNames = @[ @"Main", @"Discussion", @"The Finer Arts", @"The Community", @"Archives" ];
    STAssertEqualObjects([info.categories valueForKey:@"name"], categoryNames, nil);
    
    NSArray *forumsCounts = @[ @2, @14, @9, @4, @3 ];
    NSMutableArray *actualCounts = [NSMutableArray new];
    for (CategoryParsedInfo *category in info.categories) {
        [actualCounts addObject:@([category.forums count])];
    }
    STAssertEqualObjects(actualCounts, forumsCounts, nil);
    
    NSArray *gbsSubforumNames = @[ @"SA's Front Page Discussion", @"E/N Bullshit" ];
    STAssertEqualObjects([[[info.categories[0] forums][0] subforums] valueForKey:@"name"],
                         gbsSubforumNames, nil);
    NSArray *gbsSubforumIDs = @[ @"155", @"214" ];
    STAssertEqualObjects([[[info.categories[0] forums][0] subforums] valueForKey:@"forumID"],
                         gbsSubforumIDs, nil);
    
    NSArray *archivesForumNames = @[ @"Comedy Goldmine", @"Comedy Gas Chamber", @"Helldump Success Stories" ];
    STAssertEqualObjects([[info.categories[4] forums] valueForKey:@"name"], archivesForumNames, nil);
    NSArray *archivesForumIDs = @[ @"21", @"25", @"204" ];
    STAssertEqualObjects([[info.categories[4] forums] valueForKey:@"forumID"], archivesForumIDs, nil);
    
    STAssertEqualObjects([[[[info.categories[1] forums][0] subforums][4] subforums][0] name],
                         @"The Game Room", nil);
}

@end
