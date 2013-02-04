//
//  AwfulThread.m
//  Awful
//
//  Created by Nolan Waite on 12-05-17.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThread.h"
#import "AwfulDataStack.h"
#import "AwfulParsing.h"
#import "AwfulUser.h"
#import "GTMNSString+HTML.h"
#import "NSManagedObject+Awful.h"

@implementation AwfulThread

- (NSString *)firstIconName
{
    NSString *basename = [[self.threadIconImageURL lastPathComponent]
                          stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}

- (NSString *)secondIconName
{
    NSString *basename = [[self.threadIconImageURL2 lastPathComponent]
                          stringByDeletingPathExtension];
    return [basename stringByAppendingPathExtension:@"png"];
}

- (BOOL)beenSeen
{
    return self.totalUnreadPostsValue > -1;
}

+ (NSSet *)keyPathsForValuesAffectingBeenSeen
{
    return [NSSet setWithObject:@"totalUnreadPosts"];
}

+ (NSArray *)threadsCreatedOrUpdatedWithParsedInfo:(NSArray *)threadInfos
{
    NSMutableDictionary *existingThreads = [NSMutableDictionary new];
    NSArray *threadIDs = [threadInfos valueForKey:@"threadID"];
    for (AwfulThread *thread in [self fetchAllMatchingPredicate:@"threadID IN %@", threadIDs]) {
        existingThreads[thread.threadID] = thread;
    }
    NSMutableDictionary *existingUsers = [NSMutableDictionary new];
    NSArray *usernames = [threadInfos valueForKeyPath:@"author.username"];
    for (AwfulUser *user in [AwfulUser fetchAllMatchingPredicate:@"username IN %@", usernames]) {
        existingUsers[user.username] = user;
    }
    
    for (ThreadParsedInfo *info in threadInfos) {
        if ([info.threadID length] == 0) {
            NSLog(@"ignoring ID-less thread (announcement?)");
            continue;
        }
        AwfulThread *thread = existingThreads[info.threadID] ?: [AwfulThread insertNew];
        [info applyToObject:thread];
        if (!thread.author) thread.author = [AwfulUser insertNew];
        [info.author applyToObject:thread.author];
        existingUsers[thread.author.username] = thread.author;
        existingThreads[thread.threadID] = thread;
    }
    [[AwfulDataStack sharedDataStack] save];
    return [existingThreads allValues];
}

+ (NSArray *)threadsCreatedOrUpdatedWithJSON:(NSDictionary *)json
{
    NSMutableDictionary *existingThreads = [NSMutableDictionary new];
    NSArray *threadIDs = [json valueForKeyPath:@"threads.threadid.stringValue"];
    for (AwfulThread *thread in [self fetchAllMatchingPredicate:@"threadID in %@", threadIDs]) {
        existingThreads[thread.threadID] = thread;
    }
    
    for (NSDictionary *info in json[@"threads"]) {
        NSString *threadID = [info[@"threadid"] stringValue];
        AwfulThread *thread = existingThreads[threadID] ?: [AwfulThread insertNew];
        thread.threadID = threadID;
        // TODO fix for numeric-looking usernames coming in as JSON numbers. Remove when fixed
        // server-side.
        if ([info[@"lastposter"] respondsToSelector:@selector(stringValue)]) {
            thread.lastPostAuthorName = [info[@"lastposter"] stringValue];
        } else {
            thread.lastPostAuthorName = info[@"lastposter"];
        }
        thread.lastPostDate = [NSDate dateWithTimeIntervalSince1970:[info[@"lastpost"] doubleValue]];
        NSDictionary *icon = json[@"icons"][[info[@"iconid"] stringValue]];
        thread.threadIconImageURL = [NSURL URLWithString:icon[@"iconpath"]];
        if (info[@"type"]) {
            thread.threadIconImageURL2 = SecondaryIconURLForType(info[@"type"]);
        } else {
            thread.threadIconImageURL2 = nil;
        }
        NSNumber *starCategory = info[@"bookmark_category"];
        if ([starCategory isEqual:[NSNull null]]) {
            thread.isBookmarkedValue = NO;
            thread.starCategoryValue = AwfulStarCategoryNone;
        } else {
            thread.isBookmarkedValue = YES;
            thread.starCategoryValue = (AwfulStarCategory)[starCategory integerValue];
        }
        thread.isClosedValue = ![info[@"open"] boolValue];
        thread.isStickyValue = [info[@"sticky"] boolValue];
        thread.threadID = [info[@"threadid"] stringValue];
        thread.threadVotes = info[@"vote_count"];
        if (![info[@"vote_score_sum"] isEqual:[NSNull null]]) {
            NSDecimal rating = [info[@"vote_score_average"] decimalValue];
            thread.threadRating = [NSDecimalNumber decimalNumberWithDecimal:rating];
        } else {
            thread.threadRating = nil;
        }
        thread.title = [info[@"title"] gtm_stringByUnescapingFromHTML];
        thread.totalReplies = info[@"replycount"];
        thread.totalUnreadPosts = info[@"newpostcount"] ?: @(-1);
        
        NSDictionary *authorJSON = @{
            @"userid": info[@"postuserid"],
            @"username": info[@"postusername"]
        };
        thread.author = [AwfulUser userCreatedOrUpdatedFromJSON:authorJSON];
        
        existingThreads[thread.threadID] = thread;
    }
    [[AwfulDataStack sharedDataStack] save];
    return [existingThreads allValues];
}

static NSURL * SecondaryIconURLForType(NSString *type)
{
    static NSDictionary *types;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        types = @{
            @"ASK": @"http://fi.somethingawful.com/ama.gif",
            @"TELL": @"http://fi.somethingawful.com/tma.gif",
            @"BUY": @"http://fi.somethingawful.com/forums/posticons/icon-38-buying.gif",
            @"TRADE": @"http://fi.somethingawful.com/forums/posticons/icon-46-trading.gif",
            @"AUCTION": @"http://fi.somethingawful.com/forums/posticons/icon-52-trading.gif",
            @"SELL": @"http://fi.somethingawful.com/forums/posticons/icon-37-selling.gif"
        };
    });
    return [NSURL URLWithString:types[type]];
}

#pragma mark - _AwfulThread

- (void)setTotalReplies:(NSNumber *)totalReplies
{
    [self willChangeValueForKey:AwfulThreadAttributes.totalReplies];
    self.primitiveTotalReplies = totalReplies;
    [self didChangeValueForKey:AwfulThreadAttributes.totalReplies];
    NSInteger minimumNumberOfPages = 1 + [totalReplies integerValue] / 40;
    if (minimumNumberOfPages > self.numberOfPagesValue) {
        self.numberOfPagesValue = minimumNumberOfPages;
    }
}

@end
