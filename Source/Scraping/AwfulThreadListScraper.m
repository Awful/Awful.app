//  AwfulThreadListScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadListScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulScanner.h"
#import "AwfulStarCategory.h"
#import "HTMLNode+CachedSelector.h"
#import "NSURL+QueryDictionary.h"
#import "Awful-Swift.h"

@interface AwfulThreadListScraper ()

@property (strong, nonatomic) Forum *forum;

@property (copy, nonatomic) NSArray *threads;

@end

@implementation AwfulThreadListScraper

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
    HTMLElement *body = [self.node awful_firstNodeMatchingCachedSelector:@"body"];
    if (body[@"data-forum"]) {
        ForumKey *forumKey = [[ForumKey alloc] initWithForumID:body[@"data-forum"]];
        self.forum = [Forum objectWithKey:forumKey inManagedObjectContext:self.managedObjectContext];
        self.forum.canPost = !![body firstNodeMatchingSelector:@"ul.postbuttons a[href*='newthread']"];
    }
    
    HTMLElement *breadcrumbsDiv = [self.node awful_firstNodeMatchingCachedSelector:@"div.breadcrumbs"];
    
    // The first hierarchy link (if any) is the category. The rest are forums/subforums.
    NSArray *hierarchyLinks = [breadcrumbsDiv awful_nodesMatchingCachedSelector:@"a[href *= 'forumdisplay.php']"];

    HTMLElement *forumLink = hierarchyLinks.lastObject;
    if (forumLink) {
        self.forum.name = forumLink.textContent;
    }
    if (hierarchyLinks.count > 0) {
        HTMLElement *groupLink = hierarchyLinks.firstObject;
        NSURL *URL = [NSURL URLWithString:groupLink[@"href"]];
        NSString *groupID = URL.queryDictionary[@"forumid"];
        ForumGroupKey *groupKey = [[ForumGroupKey alloc] initWithGroupID:groupID];
        ForumGroup *group = [ForumGroup objectForKey:groupKey inManagedObjectContext:self.managedObjectContext];
        group.name = groupLink.textContent;
        NSArray *subforumLinks = [hierarchyLinks subarrayWithRange:NSMakeRange(1, hierarchyLinks.count - 1)];
        Forum *currentForum;
        for (HTMLElement *subforumLink in subforumLinks.reverseObjectEnumerator) {
            NSURL *URL = [NSURL URLWithString:subforumLink[@"href"]];
            ForumKey *subforumKey = [[ForumKey alloc] initWithForumID:URL.queryDictionary[@"forumid"]];
            Forum *subforum = [Forum objectWithKey:subforumKey inManagedObjectContext:self.managedObjectContext];
            subforum.name = subforumLink.textContent;
            subforum.group = group;
            currentForum.parentForum = subforum;
            currentForum = subforum;
        }
    }
    
    // TODO parse number of pages so we know whether to enable pull-for-more. (Is this foolproof if someone's set to not 40 posts per page? Dunno if forumdisplay.php handles perpage=40.)
    
    HTMLElement *threadTagsDiv = [self.node awful_firstNodeMatchingCachedSelector:@"div.thread_tags"];
    if (threadTagsDiv) {
        NSMutableArray *threadTagKeys = [NSMutableArray new];
        for (HTMLElement *link in [threadTagsDiv awful_nodesMatchingCachedSelector:@"a[href*='posticon']"]) {
            NSURL *URL = [NSURL URLWithString:link[@"href"]];
            NSString *threadTagID = URL.queryDictionary[@"posticon"];
            HTMLElement *image = [link awful_firstNodeMatchingCachedSelector:@"img"];
            NSURL *imageURL = [NSURL URLWithString:image[@"src"]];
            [threadTagKeys addObject:[[ThreadTagKey alloc] initWithImageURL:imageURL threadTagID:threadTagID]];
        }
        NSArray *threadTags = [ThreadTag objectsForKeys:threadTagKeys inManagedObjectContext:self.managedObjectContext];
        self.forum.threadTags = [NSMutableOrderedSet orderedSetWithArray:threadTags];
    }
    
    // Two passes over each row in the table. First, find thread, tag, and user info so we can fetch everything we already know about in a couple big batches. Later we'll update or insert everything else.
    NSArray *threadLinks = [self.node awful_nodesMatchingCachedSelector:@"tr.thread"];
    NSMutableArray *threadKeys = [NSMutableArray new];
    NSMutableArray *userKeys = [NSMutableArray new];
    NSMutableArray *threadTagKeys = [NSMutableArray new];
    NSMutableArray *threadDictionaries = [NSMutableArray new];
    for (HTMLElement *row in threadLinks) {
        NSMutableDictionary *threadInfo = [NSMutableDictionary new];
        
        NSString *IDAttribute = row[@"id"];
        if (IDAttribute.length == 0) {
            // probably an announcement
            [threadDictionaries addObject:threadInfo];
            continue;
        }
        
        NSString *threadID;
        AwfulScanner *scanner = [AwfulScanner scannerWithString:IDAttribute];
        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
        threadID = [scanner.string substringFromIndex:scanner.scanLocation];
        if (threadID.length > 0) {
            [threadKeys addObject:[[ThreadKey alloc] initWithThreadID:threadID]];
        } else {
            self.error = [NSError errorWithDomain:AwfulErrorDomain
                                             code:AwfulErrorCodes.parseError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Thread list parsing failed; could not find thread ID" }];
            return;
        }
        
        HTMLElement *authorProfileLink = [row awful_firstNodeMatchingCachedSelector:@"td.author a"];
        if (authorProfileLink) {
            NSURL *profileURL = [NSURL URLWithString:authorProfileLink[@"href"]];
            NSString *authorUserID = profileURL.queryDictionary[@"userid"];
            NSString *authorUsername = authorProfileLink.textContent;
            if (authorUserID.length > 0 || authorUsername.length > 0) {
                UserKey *authorKey = [[UserKey alloc] initWithUserID:authorUserID username:authorUsername];
                threadInfo[@"authorKey"] = authorKey;
                [userKeys addObject:authorKey];
            }
        }
        
        HTMLElement *threadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.icon img"];
        if (!threadTagImage) {
            threadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.rating img[src*='/rate/reviews']"];
        }
        if (threadTagImage) {
            NSURL *URL = [NSURL URLWithString:threadTagImage[@"src"]];
            NSString *threadTagID = URL.fragment;
            if (URL) {
                ThreadTagKey *tagKey = [[ThreadTagKey alloc] initWithImageURL:URL threadTagID:threadTagID];
                threadInfo[@"threadTagKey"] = tagKey;
                [threadTagKeys addObject:tagKey];
            }
        }
        
        HTMLElement *secondaryThreadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.icon2 img"];
        if (secondaryThreadTagImage) {
            NSURL *URL = [NSURL URLWithString:secondaryThreadTagImage[@"src"]];
            NSString *threadTagID = URL.fragment;
            if (URL) {
                ThreadTagKey *secondaryTagKey = [[ThreadTagKey alloc] initWithImageURL:URL threadTagID:threadTagID];
                threadInfo[@"secondaryThreadTagKey"] = secondaryTagKey;
                [threadTagKeys addObject:secondaryTagKey];
            }
        }
        
        [threadDictionaries addObject:threadInfo];
    }
    
    if (threadKeys.count == 0) {
        return;
    }
    
    NSArray *threads = [Thread objectsForKeys:threadKeys inManagedObjectContext:self.managedObjectContext];
    NSArray *users = [User objectsForKeys:userKeys inManagedObjectContext:self.managedObjectContext];
    NSDictionary *usersByKey = [NSDictionary dictionaryWithObjects:users forKeys:[users valueForKey:@"objectKey"]];
    NSArray *threadTags = [ThreadTag objectsForKeys:threadTagKeys inManagedObjectContext:self.managedObjectContext];
    NSDictionary *threadTagsByKey = [NSDictionary dictionaryWithObjects:threadTags forKeys:[threadTags valueForKey:@"objectKey"]];
    __block NSUInteger threadIndex = 0;
    __block int32_t stickyIndex = -(int32_t)threadLinks.count;
    [threadLinks enumerateObjectsUsingBlock:^(HTMLElement *row, NSUInteger i, BOOL *stop) {
        NSDictionary *threadInfo = threadDictionaries[i];
        if (threadInfo.count == 0) {
            // probably an announcement
            return;
        }
        Thread *thread = threads[threadIndex++];
        
        HTMLElement *stickyCell = [row awful_firstNodeMatchingCachedSelector:@"td.title_sticky"];
        thread.sticky = !!stickyCell;
        if (self.forum) {
            thread.forum = self.forum;
            if (thread.sticky) {
                thread.stickyIndex = stickyIndex;
                stickyIndex++;
            } else {
                thread.stickyIndex = 0;
            }
        }
        
        HTMLElement *titleLink = [row awful_firstNodeMatchingCachedSelector:@"a.thread_title"];
        if (titleLink) {
            thread.title = titleLink.textContent;
        }
        
        UserKey *authorKey = threadInfo[@"authorKey"];
        if (authorKey) {
            User *author = usersByKey[authorKey];
            thread.author = author;
        }

        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSArray *rowClasses = [row[@"class"] componentsSeparatedByCharactersInSet:whitespace];
        thread.closed = [rowClasses containsObject:@"closed"];
        
        HTMLElement *bookmarkStarCell = [row awful_firstNodeMatchingCachedSelector:@"td.star"];
        if (bookmarkStarCell) {
            NSArray *starClasses = [bookmarkStarCell[@"class"] componentsSeparatedByCharactersInSet:whitespace];
            if ([starClasses containsObject:@"bm0"]) {
                thread.starCategory = AwfulStarCategoryOrange;
            } else if ([starClasses containsObject:@"bm1"]) {
                thread.starCategory = AwfulStarCategoryRed;
            } else if ([starClasses containsObject:@"bm2"]) {
                thread.starCategory = AwfulStarCategoryYellow;
            } else {
                thread.starCategory = AwfulStarCategoryNone;
            }
        }
        
        ThreadTagKey *threadTagKey = threadInfo[@"threadTagKey"];
        if (threadTagKey) {
            thread.threadTag = threadTagsByKey[threadTagKey];
        }
        ThreadTagKey *secondaryThreadTagKey = threadInfo[@"secondaryThreadTagKey"];
        if (secondaryThreadTagKey) {
            thread.secondaryThreadTag = threadTagsByKey[secondaryThreadTagKey];
        }
        
        HTMLElement *repliesCell = [row awful_firstNodeMatchingCachedSelector:@"td.replies"];
        if (repliesCell) {
            HTMLElement *repliesLink = [repliesCell awful_firstNodeMatchingCachedSelector:@"a"];
            thread.totalReplies = (int32_t)(repliesLink ?: repliesCell).innerHTML.integerValue;
        }
        
        HTMLElement *unreadLink = [row awful_firstNodeMatchingCachedSelector:@"a.count b"];
        if (unreadLink) {
            thread.seenPosts = (int32_t)(thread.totalReplies + 1 - unreadLink.innerHTML.integerValue);
        } else if ([row awful_firstNodeMatchingCachedSelector:@"a.x"]) {
            thread.seenPosts = thread.totalReplies + 1;
        } else {
            thread.seenPosts = 0;
        }
        
        HTMLElement *ratingImage = [row awful_firstNodeMatchingCachedSelector:@"td.rating img"];
        if (ratingImage) {
            AwfulScanner *scanner = [AwfulScanner scannerWithString:ratingImage[@"title"]];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
            int numberOfVotes;
            BOOL ok = [scanner scanInt:&numberOfVotes];
            if (ok) {
                thread.numberOfVotes = numberOfVotes;
            }
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
            float average;
            ok = [scanner scanFloat:&average];
            if (ok) {
                thread.rating = average;
            }
        }
        
        HTMLElement *lastPostDateDiv = [row awful_firstNodeMatchingCachedSelector:@"td.lastpost div.date"];
        if (lastPostDateDiv) {
            NSDate *lastPostDate = [LastPostDateParser() dateFromString:lastPostDateDiv.innerHTML];
            if (lastPostDate) {
                thread.lastPostDate = lastPostDate;
            }
        }
        
        HTMLElement *lastPostAuthorLink = [row awful_firstNodeMatchingCachedSelector:@"td.lastpost a.author"];
        if (lastPostAuthorLink) {
            thread.lastPostAuthorName = lastPostAuthorLink.textContent;
        }
    }];
    
    self.threads = threads;
}

static AwfulCompoundDateParser * LastPostDateParser(void)
{
    static AwfulCompoundDateParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[AwfulCompoundDateParser alloc] initWithFormats:@[ @"h:mm a MMM d, yyyy",
                                                                     @"HH:mm MMM d, yyyy" ]];
    });
    return parser;
}

@end
