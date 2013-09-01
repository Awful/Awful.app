//
//  ForumTests.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import "ParsingTests.h"

@interface ForumTests : ParsingTests @end
@implementation ForumTests

+ (NSString *)fixtureFilename { return @"forumdisplay.html"; }

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
    
    STAssertEqualObjects([threadInfos[1] threadID], @"3520449", nil);
    STAssertEqualObjects([threadInfos[8] threadID], @"3521148", nil);
    
    STAssertEqualObjects([threadInfos[7] title], @"End of an Era: Remembering a Hero of the United States Congress", nil);
    
    STAssertTrue([threadInfos[0] isSticky], nil);
    STAssertFalse([threadInfos[1] isSticky] || [threadInfos[10] isSticky], nil);
    
    STAssertEqualObjects([[threadInfos[12] threadIconImageURL] absoluteString],
                         @"http://fi.somethingawful.com/forums/posticons/lf-gotmine.gif#534", nil);
    
    STAssertEqualObjects([[threadInfos[16] author] username], @"WYA", nil);
    
    STAssertTrue([threadInfos[12] seen] && [threadInfos[13] seen], nil);
    STAssertFalse([threadInfos[19] seen] || [threadInfos[24] seen], nil);
    
    STAssertFalse([threadInfos[6] isClosed], nil);
    
    STAssertEquals([threadInfos[0] starCategory], 3, nil);
    
    STAssertEquals([threadInfos[0] seenPosts], 12, nil);
    STAssertEquals([threadInfos[1] seenPosts], 0, nil);
    STAssertEquals([threadInfos[11] seenPosts], 33440, nil);
    
    STAssertEquals([threadInfos[38] totalReplies], 343, nil);
    
    STAssertEquals([threadInfos[8] threadVotes], 63, nil);
    STAssertEqualObjects([threadInfos[8] threadRating], [NSDecimalNumber decimalNumberWithString:@"1.58"], nil);
    
    STAssertEqualObjects([threadInfos[30] lastPostAuthorName], @"richardfun", nil);
    
    STAssertNotNil([threadInfos[35] lastPostDate], nil);
}

@end
