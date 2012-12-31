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

- (void)testThreads
{
    NSArray *threadInfos = [ThreadParsedInfo threadsWithHTMLData:self.fixture];
    STAssertEquals([threadInfos count], 40U, nil);
    
    STAssertEqualObjects([[threadInfos lastObject] forumID], @"46", nil);
    
    STAssertEqualObjects([threadInfos[1] threadID], @"3508391", nil);
    STAssertEqualObjects([threadInfos[8] threadID], @"3510496", nil);
    
    STAssertEqualObjects([threadInfos[7] title], @"UK Political Cartoons Megathread Part 2", nil);
    
    STAssertTrue([threadInfos[0] isSticky] && [threadInfos[3] isSticky], nil);
    STAssertFalse([threadInfos[5] isSticky] || [threadInfos[10] isSticky], nil);
    
    STAssertEqualObjects([[threadInfos[12] threadIconImageURL] absoluteString],
                         @"http://fi.somethingawful.com/forums/posticons/lf-marx.png#522", nil);
    
    STAssertEqualObjects([threadInfos[16] authorName], @"ChlamydiaJones", nil);
    
    STAssertTrue([threadInfos[17] seen] && [threadInfos[4] seen], nil);
    STAssertFalse([threadInfos[19] seen] || [threadInfos[24] seen], nil);
    
    STAssertFalse([threadInfos[6] isClosed], nil);
    
    STAssertEquals([threadInfos[0] starCategory], 3, nil);
    STAssertEquals([threadInfos[30] starCategory], 1, nil);
    
    STAssertEquals([threadInfos[30] totalUnreadPosts], 0, nil);
    STAssertEquals([threadInfos[31] totalUnreadPosts], -1, nil);
    STAssertEquals([threadInfos[29] totalUnreadPosts], 48, nil);
    
    STAssertEquals([threadInfos[38] totalReplies], 1708, nil);
    
    STAssertEquals([threadInfos[33] threadVotes], 22, nil);
    STAssertEqualObjects([threadInfos[33] threadRating], [NSDecimalNumber decimalNumberWithString:@"2.87"], nil);
    
    STAssertEqualObjects([threadInfos[30] lastPostAuthorName], @"Kafka Esq.", nil);
    
    STAssertNotNil([threadInfos[35] lastPostDate], nil);
}

@end
