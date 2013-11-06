//  AwfulThreadListScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadListScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulModels.h"
#import "AwfulScanner.h"
#import "GTMNSString+HTML.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulThreadListScraper ()

@property (strong, nonatomic) AwfulCompoundDateParser *lastPostDateParser;

@end

@implementation AwfulThreadListScraper

- (AwfulCompoundDateParser *)lastPostDateParser
{
    if (_lastPostDateParser) return _lastPostDateParser;
    _lastPostDateParser = [[AwfulCompoundDateParser alloc] initWithFormats:@[ @"HH:mm MMM d, yyyy",
                                                                              @"h:mm a MMM d, yyyy" ]];
    return _lastPostDateParser;
}

#pragma mark - AwfulDocumentScraper

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError **)error
{
    AwfulForum *forum;
    HTMLElementNode *body = [document firstNodeMatchingSelector:@"body"];
    if (body[@"data-forum"]) {
        forum = [AwfulForum fetchOrInsertForumInManagedObjectContext:managedObjectContext withID:body[@"data-forum"]];
    }
    
    HTMLElementNode *breadcrumbsDiv = [document firstNodeMatchingSelector:@"div.breadcrumbs"];
    
    // The first hierarchy link (if any) is the category. The rest are forums/subforums.
    NSArray *hierarchyLinks = [breadcrumbsDiv nodesMatchingSelector:@"a[href *= 'forumdisplay.php']"];

    HTMLElementNode *forumLink = hierarchyLinks.lastObject;
    if (forumLink) {
        forum.name = [forumLink.innerHTML gtm_stringByUnescapingFromHTML];
    }
    if (hierarchyLinks.count > 0) {
        HTMLElementNode *categoryLink = hierarchyLinks.firstObject;
        NSURL *URL = [NSURL URLWithString:categoryLink[@"href"]];
        NSString *categoryID = URL.queryDictionary[@"forumid"];
        AwfulCategory *category = [AwfulCategory firstOrNewCategoryWithCategoryID:categoryID
                                                           inManagedObjectContext:managedObjectContext];
        category.name = [categoryLink.innerHTML gtm_stringByUnescapingFromHTML];
        NSArray *subforumLinks = [hierarchyLinks subarrayWithRange:NSMakeRange(1, hierarchyLinks.count - 1)];
        AwfulForum *currentForum;
        for (HTMLElementNode *subforumLink in subforumLinks.reverseObjectEnumerator) {
            NSURL *URL = [NSURL URLWithString:subforumLink[@"href"]];
            NSString *subforumID = URL.queryDictionary[@"forumid"];
            AwfulForum *subforum = [AwfulForum fetchOrInsertForumInManagedObjectContext:managedObjectContext
                                                                                 withID:subforumID];
            subforum.name = [subforumLink.innerHTML gtm_stringByUnescapingFromHTML];
            subforum.category = category;
            currentForum.parentForum = subforum;
            currentForum = subforum;
        }
    }
    
    // TODO parse number of pages so we know whether to enable pull-for-more.
    
    NSArray *threadLinks = [document nodesMatchingSelector:@"tr.thread"];
    NSMutableArray *threads = [NSMutableArray new];
    int32_t stickyIndex = -(int32_t)threadLinks.count;
    for (HTMLElementNode *row in threadLinks) {
        NSString *threadID;
        {
            AwfulScanner *scanner = [AwfulScanner scannerWithString:row[@"id"]];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
            threadID = [scanner.string substringFromIndex:scanner.scanLocation];
        }
        if (threadID.length == 0) {
            if (error) {
                *error = [NSError errorWithDomain:AwfulErrorDomain
                                             code:AwfulErrorCodes.parseError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Thread list parsing failed; could not find thread ID" }];
            }
            continue;
        }
        AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID inManagedObjectContext:managedObjectContext];
        [threads addObject:thread];
        HTMLElementNode *stickyCell = [row firstNodeMatchingSelector:@"td.title_sticky"];
        thread.sticky = !!stickyCell;
        if (forum) {
            thread.forum = forum;
            if (thread.sticky) {
                thread.stickyIndex = stickyIndex;
                stickyIndex++;
            } else {
                thread.stickyIndex = 0;
            }
        }
        HTMLElementNode *titleLink = [row firstNodeMatchingSelector:@"a.thread_title"];
        if (titleLink) {
            thread.title = [titleLink.innerHTML gtm_stringByUnescapingFromHTML];
        }
        HTMLElementNode *threadTagImage = [row firstNodeMatchingSelector:@"td.icon img"];
        if (!threadTagImage) {
            threadTagImage = [row firstNodeMatchingSelector:@"td.rating img[src*='/rate/reviews']"];
        }
        if (threadTagImage) {
            thread.threadTagURL = [NSURL URLWithString:threadTagImage[@"src"] relativeToURL:documentURL];
        }
        HTMLElementNode *secondaryThreadTagImage = [row firstNodeMatchingSelector:@"td.icon2 img"];
        if (secondaryThreadTagImage) {
            thread.secondaryThreadTagURL = [NSURL URLWithString:secondaryThreadTagImage[@"src"] relativeToURL:documentURL];
        }
        HTMLElementNode *authorProfileLink = [row firstNodeMatchingSelector:@"td.author a"];
        if (authorProfileLink) {
            NSString *authorUsername = [[authorProfileLink innerHTML] gtm_stringByUnescapingFromHTML];
            NSURL *profileURL = [NSURL URLWithString:authorProfileLink[@"href"]];
            NSString *authorUserID = profileURL.queryDictionary[@"userid"];
            AwfulUser *author = [AwfulUser firstOrNewUserWithUserID:authorUserID
                                                           username:authorUsername
                                             inManagedObjectContext:managedObjectContext];
            if (author) {
                thread.author = author;
            }
        }
        NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSArray *rowClasses = [row[@"class"] componentsSeparatedByCharactersInSet:whitespace];
        thread.closed = [rowClasses containsObject:@"closed"];
        HTMLElementNode *bookmarkStarCell = [row firstNodeMatchingSelector:@"td.star"];
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
        HTMLElementNode *repliesCell = [row firstNodeMatchingSelector:@"td.replies"];
        if (repliesCell) {
            HTMLElementNode *repliesLink = [repliesCell firstNodeMatchingSelector:@"a"];
            thread.totalReplies = (repliesLink ?: repliesCell).innerHTML.integerValue;
        }
        HTMLElementNode *unreadLink = [row firstNodeMatchingSelector:@"a.count b"];
        if (unreadLink) {
            thread.seenPosts = thread.totalReplies + 1 - unreadLink.innerHTML.integerValue;
        } else if ([row firstNodeMatchingSelector:@"a.x"]) {
            thread.seenPosts = thread.totalReplies + 1;
        } else {
            thread.seenPosts = 0;
        }
        HTMLElementNode *ratingImage = [row firstNodeMatchingSelector:@"td.rating img"];
        if (ratingImage) {
            AwfulScanner *scanner = [AwfulScanner scannerWithString:ratingImage[@"title"]];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
            NSInteger numberOfVotes;
            BOOL ok = [scanner scanInteger:&numberOfVotes];
            if (ok) {
                thread.numberOfVotes = numberOfVotes;
            }
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
            NSDecimal average;
            ok = [scanner scanDecimal:&average];
            if (ok) {
                thread.rating = [NSDecimalNumber decimalNumberWithDecimal:average];
            }
        }
        HTMLElementNode *lastPostDateDiv = [row firstNodeMatchingSelector:@"td.lastpost div.date"];
        if (lastPostDateDiv) {
            NSDate *lastPostDate = [self.lastPostDateParser dateFromString:lastPostDateDiv.innerHTML];
            if (lastPostDate) {
                thread.lastPostDate = lastPostDate;
            }
        }
        HTMLElementNode *lastPostAuthorLink = [row firstNodeMatchingSelector:@"td.lastpost a.author"];
        if (lastPostAuthorLink) {
            thread.lastPostAuthorName = lastPostAuthorLink.innerHTML;
        }
    }
    [managedObjectContext save:error];
    return threads;
}

@end
