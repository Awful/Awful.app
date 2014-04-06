//  AwfulThreadListScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadListScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulModels.h"
#import "AwfulScanner.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulThreadListScraper ()

@property (strong, nonatomic) AwfulForum *forum;

@property (copy, nonatomic) NSArray *threads;

@end

@implementation AwfulThreadListScraper

- (void)scrape
{
    HTMLElement *body = [self.node awful_firstNodeMatchingCachedSelector:@"body"];
    if (body[@"data-forum"]) {
        self.forum = [AwfulForum fetchOrInsertForumInManagedObjectContext:self.managedObjectContext withID:body[@"data-forum"]];
    }
    
    HTMLElement *breadcrumbsDiv = [self.node awful_firstNodeMatchingCachedSelector:@"div.breadcrumbs"];
    
    // The first hierarchy link (if any) is the category. The rest are forums/subforums.
    NSArray *hierarchyLinks = [breadcrumbsDiv awful_nodesMatchingCachedSelector:@"a[href *= 'forumdisplay.php']"];

    HTMLElement *forumLink = hierarchyLinks.lastObject;
    if (forumLink) {
        self.forum.name = [forumLink.textContent gtm_stringByUnescapingFromHTML];
    }
    if (hierarchyLinks.count > 0) {
        HTMLElement *categoryLink = hierarchyLinks.firstObject;
        NSURL *URL = [NSURL URLWithString:categoryLink[@"href"]];
        NSString *categoryID = URL.queryDictionary[@"forumid"];
        AwfulCategory *category = [AwfulCategory firstOrNewCategoryWithCategoryID:categoryID inManagedObjectContext:self.managedObjectContext];
        category.name = [categoryLink.innerHTML gtm_stringByUnescapingFromHTML];
        NSArray *subforumLinks = [hierarchyLinks subarrayWithRange:NSMakeRange(1, hierarchyLinks.count - 1)];
        AwfulForum *currentForum;
        for (HTMLElement *subforumLink in subforumLinks.reverseObjectEnumerator) {
            NSURL *URL = [NSURL URLWithString:subforumLink[@"href"]];
            NSString *subforumID = URL.queryDictionary[@"forumid"];
            AwfulForum *subforum = [AwfulForum fetchOrInsertForumInManagedObjectContext:self.managedObjectContext withID:subforumID];
            subforum.name = [subforumLink.innerHTML gtm_stringByUnescapingFromHTML];
            subforum.category = category;
            currentForum.parentForum = subforum;
            currentForum = subforum;
        }
    }
    
    // TODO parse number of pages so we know whether to enable pull-for-more.
    
    HTMLElement *threadTagsDiv = [self.node awful_firstNodeMatchingCachedSelector:@"div.thread_tags"];
    if (threadTagsDiv) {
        NSMutableOrderedSet *threadTags = [NSMutableOrderedSet new];
        for (HTMLElement *link in [threadTagsDiv awful_nodesMatchingCachedSelector:@"a[href*='posticon']"]) {
            NSURL *URL = [NSURL URLWithString:link[@"href"]];
            NSString *threadTagID = URL.queryDictionary[@"posticon"];
            HTMLElement *image = [link awful_firstNodeMatchingCachedSelector:@"img"];
            NSURL *imageURL = [NSURL URLWithString:image[@"src"]];
            AwfulThreadTag *threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:threadTagID
                                                                              threadTagURL:imageURL
                                                                    inManagedObjectContext:self.managedObjectContext];
            [threadTags addObject:threadTag];
        }
        self.forum.threadTags = threadTags;
    }
    
    // Two passes over each row in the table. First, find thread, tag, and user info so we can fetch everything we already know about in a couple big batches. Later we'll update or insert everything else.
    NSArray *threadLinks = [self.node awful_nodesMatchingCachedSelector:@"tr.thread"];
    NSMutableArray *threadIDs = [NSMutableArray new];
    NSMutableArray *userIDs = [NSMutableArray new];
    NSMutableArray *usernames = [NSMutableArray new];
    NSMutableArray *threadTagIDs = [NSMutableArray new];
    NSMutableArray *threadTagImageNames = [NSMutableArray new];
    NSMutableArray *threadDictionaries = [NSMutableArray new];
    for (HTMLElement *row in threadLinks) {
        NSMutableDictionary *threadInfo = [NSMutableDictionary new];
        NSString *threadID;
        AwfulScanner *scanner = [AwfulScanner scannerWithString:row[@"id"]];
        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
        threadID = [scanner.string substringFromIndex:scanner.scanLocation];
        if (threadID.length > 0) {
            threadInfo[@"threadID"] = threadID;
            [threadIDs addObject:threadID];
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
            if (authorUserID.length > 0) {
                threadInfo[@"authorUserID"] = authorUserID;
                [userIDs addObject:authorUserID];
            }
            NSString *authorUsername = [[authorProfileLink innerHTML] gtm_stringByUnescapingFromHTML];
            if (authorUsername.length > 0) {
                threadInfo[@"authorUsername"] = authorUsername;
                [usernames addObject:authorUsername];
            }
        }
        
        HTMLElement *threadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.icon img"];
        if (!threadTagImage) {
            threadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.rating img[src*='/rate/reviews']"];
        }
        if (threadTagImage) {
            NSURL *URL = [NSURL URLWithString:threadTagImage[@"src"]];
            NSString *threadTagID = URL.fragment;
            if (threadTagID.length > 0) {
                threadInfo[@"threadTagID"] = threadTagID;
                [threadTagIDs addObject:threadTagID];
            }
            NSString *imageName = URL.lastPathComponent.stringByDeletingPathExtension;
            if (imageName.length > 0) {
                threadInfo[@"threadTagImageName"] = imageName;
                [threadTagImageNames addObject:imageName];
            }
        }
        
        HTMLElement *secondaryThreadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.icon2 img"];
        if (secondaryThreadTagImage) {
            NSURL *URL = [NSURL URLWithString:secondaryThreadTagImage[@"src"]];
            NSString *threadTagID = URL.fragment;
            if (threadTagID.length > 0) {
                threadInfo[@"secondaryThreadTagID"] = threadTagID;
                [threadTagIDs addObject:threadTagID];
            }
            NSString *imageName = URL.lastPathComponent.stringByDeletingPathExtension;
            if (imageName.length > 0) {
                threadInfo[@"secondaryThreadTagImageName"] = imageName;
                [threadTagImageNames addObject:imageName];
            }
        }
        
        [threadDictionaries addObject:threadInfo];
    }
    NSDictionary *fetchedThreads = [AwfulThread dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                                keyedByAttributeNamed:@"threadID"
                                                              matchingPredicateFormat:@"threadID IN %@", threadIDs];
    NSMutableDictionary *usersByID = [[AwfulUser dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                                 keyedByAttributeNamed:@"userID"
                                                               matchingPredicateFormat:@"userID IN %@", userIDs] mutableCopy];
    NSMutableDictionary *usersByName = [[AwfulUser dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                                   keyedByAttributeNamed:@"username"
                                                                 matchingPredicateFormat:@"userID = nil AND username IN %@", usernames] mutableCopy];
    NSMutableDictionary *tagsByID = [[AwfulThreadTag dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                                     keyedByAttributeNamed:@"threadTagID"
                                                                   matchingPredicateFormat:@"threadTagID IN %@", threadTagIDs] mutableCopy];
    NSMutableDictionary *tagsByImageName = [[AwfulThreadTag dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                                            keyedByAttributeNamed:@"imageName"
                                                                          matchingPredicateFormat:@"imageName IN %@", threadTagImageNames] mutableCopy];
    
    NSMutableArray *threads = [NSMutableArray new];
    __block int32_t stickyIndex = -(int32_t)threadLinks.count;
    [threadLinks enumerateObjectsUsingBlock:^(HTMLElement *row, NSUInteger i, BOOL *stop) {
        NSDictionary *threadInfo = threadDictionaries[i];
        NSString *threadID = threadInfo[@"threadID"];
        AwfulThread *thread = fetchedThreads[threadID];
        if (!thread) {
            thread = [AwfulThread insertInManagedObjectContext:self.managedObjectContext];
            thread.threadID = threadID;
        }
        [threads addObject:thread];
        
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
            thread.title = [titleLink.innerHTML gtm_stringByUnescapingFromHTML];
        }
        
        NSString *authorUserID = threadInfo[@"authorUserID"];
        NSString *authorUsername = threadInfo[@"authorUsername"];
        AwfulUser *author = usersByID[authorUserID] ?: usersByName[authorUsername];
        if (!author && (authorUserID || authorUsername)) {
            author = [AwfulUser insertInManagedObjectContext:self.managedObjectContext];
        }
        if (authorUserID) {
            author.userID = authorUserID;
            usersByID[authorUserID] = author;
        }
        if (authorUsername) {
            author.username = authorUsername;
            usersByName[authorUsername] = author;
        }
        if (author) {
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
        
        NSString *threadTagID = threadInfo[@"threadTagID"];
        NSString *threadTagImageName = threadInfo[@"threadTagImageName"];
        if (threadTagID || threadTagImageName) {
            AwfulThreadTag *threadTag;
            if (threadTagID) {
                threadTag = tagsByID[threadTagID];
            } else if (threadTagImageName) {
                threadTag = tagsByImageName[threadTagImageName];
            }
            if (!threadTag) {
                threadTag = [AwfulThreadTag insertInManagedObjectContext:self.managedObjectContext];
                if (threadTagID) {
                    threadTag.threadTagID = threadTagID;
                }
                if (threadTagImageName) {
                    threadTag.imageName = threadTagImageName;
                }
            }
            if (threadTag.threadTagID.length > 0) {
                tagsByID[threadTag.threadTagID] = threadTag;
            }
            if (threadTag.imageName.length > 0) {
                tagsByImageName[threadTag.imageName] = threadTag;
            }
            thread.threadTag = threadTag;
        }
        
        NSString *secondaryThreadTagID = threadInfo[@"secondaryThreadTagID"];
        NSString *secondaryThreadTagImageName = threadInfo[@"secondaryThreadTagImageName"];
        if (secondaryThreadTagID || secondaryThreadTagImageName) {
            AwfulThreadTag *secondaryThreadTag;
            if (secondaryThreadTagID) {
                secondaryThreadTag = tagsByID[secondaryThreadTagID];
            } else if (threadTagImageName) {
                secondaryThreadTag = tagsByImageName[secondaryThreadTagImageName];
            }
            if (!secondaryThreadTag) {
                secondaryThreadTag = [AwfulThreadTag insertInManagedObjectContext:self.managedObjectContext];
                if (secondaryThreadTagID) {
                    secondaryThreadTag.threadTagID = secondaryThreadTagID;
                }
                if (secondaryThreadTagImageName) {
                    secondaryThreadTag.imageName = secondaryThreadTagImageName;
                }
            }
            if (secondaryThreadTag.threadTagID.length > 0) {
                tagsByID[secondaryThreadTag.threadTagID] = secondaryThreadTag;
            }
            if (secondaryThreadTag.imageName.length > 0) {
                tagsByImageName[secondaryThreadTag.imageName] = secondaryThreadTag;
            }
            thread.secondaryThreadTag = secondaryThreadTag;
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
        
        HTMLElement *lastPostDateDiv = [row awful_firstNodeMatchingCachedSelector:@"td.lastpost div.date"];
        if (lastPostDateDiv) {
            NSDate *lastPostDate = [LastPostDateParser() dateFromString:lastPostDateDiv.innerHTML];
            if (lastPostDate) {
                thread.lastPostDate = lastPostDate;
            }
        }
        
        HTMLElement *lastPostAuthorLink = [row awful_firstNodeMatchingCachedSelector:@"td.lastpost a.author"];
        if (lastPostAuthorLink) {
            thread.lastPostAuthorName = [lastPostAuthorLink.textContent gtm_stringByUnescapingFromHTML];
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
