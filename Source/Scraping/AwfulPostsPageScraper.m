//  AwfulPostsPageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsPageScraper.h"
#import "AwfulAuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulModels.h"
#import "AwfulScanner.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import <HTMLReader/HTMLTextNode.h>
#import "NSURL+QueryDictionary.h"

@interface AwfulPostsPageScraper ()

@property (strong, nonatomic) AwfulCompoundDateParser *postDateParser;
@property (strong, nonatomic) AwfulAuthorScraper *authorScraper;

@end

@implementation AwfulPostsPageScraper

- (AwfulCompoundDateParser *)postDateParser
{
    if (!_postDateParser) _postDateParser = [AwfulCompoundDateParser postDateParser];
    return _postDateParser;
}

- (AwfulAuthorScraper *)authorScraper
{
    if (!_authorScraper) _authorScraper = [AwfulAuthorScraper new];
    return _authorScraper;
}

#pragma mark - AwfulDocumentScraper

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError **)error
{
    AwfulThread *thread;
    AwfulForum *forum;
    HTMLElement *body = [document awful_firstNodeMatchingCachedSelector:@"body"];
    thread = [AwfulThread firstOrNewThreadWithThreadID:body[@"data-thread"] inManagedObjectContext:managedObjectContext];
    forum = [AwfulForum fetchOrInsertForumInManagedObjectContext:managedObjectContext withID:body[@"data-forum"]];
    thread.forum = forum;
    
    HTMLElement *breadcrumbsDiv = [body awful_firstNodeMatchingCachedSelector:@"div.breadcrumbs"];
    
    // Last hierarchy link is the thread.
    // First hierarchy link is the category.
    // Intervening hierarchy links are forums/subforums.
    NSArray *hierarchyLinks = [breadcrumbsDiv awful_nodesMatchingCachedSelector:@"a[href *= 'id=']"];
    
    HTMLElement *threadLink = hierarchyLinks.lastObject;
    thread.title = [threadLink.innerHTML gtm_stringByUnescapingFromHTML];
    if (hierarchyLinks.count > 1) {
        HTMLElement *categoryLink = hierarchyLinks.firstObject;
        NSURL *URL = [NSURL URLWithString:categoryLink[@"href"]];
        NSString *categoryID = URL.queryDictionary[@"forumid"];
        AwfulCategory *category = [AwfulCategory firstOrNewCategoryWithCategoryID:categoryID
                                                           inManagedObjectContext:managedObjectContext];
        category.name = [categoryLink.innerHTML gtm_stringByUnescapingFromHTML];
        NSArray *subforumLinks = [hierarchyLinks subarrayWithRange:NSMakeRange(1, hierarchyLinks.count - 2)];
        AwfulForum *currentForum;
        for (HTMLElement *subforumLink in subforumLinks.reverseObjectEnumerator) {
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
    
    HTMLElement *closedImage = [body awful_firstNodeMatchingCachedSelector:@"ul.postbuttons a[href *= 'newreply'] img[src *= 'closed']"];
    thread.closed = !!closedImage;
    
    NSString *singleUserID = documentURL.queryDictionary[@"userid"];
    AwfulUser *singleUser;
    if (singleUserID) {
        singleUser = [AwfulUser firstOrNewUserWithUserID:singleUserID username:nil inManagedObjectContext:managedObjectContext];
    }
    
    HTMLElement *pagesDiv = [body awful_firstNodeMatchingCachedSelector:@"div.pages"];
    HTMLElement *pagesSelect = [pagesDiv awful_firstNodeMatchingCachedSelector:@"select"];
    int32_t numberOfPages = 0;
    int32_t currentPage = 0;
    if (pagesDiv) {
        if (pagesSelect) {
            HTMLElement *lastOption = [pagesSelect awful_nodesMatchingCachedSelector:@"option"].lastObject;
            NSString *pageValue = lastOption[@"value"];
            numberOfPages = (int32_t)pageValue.integerValue;
            HTMLElement *selectedOption = [pagesSelect awful_firstNodeMatchingCachedSelector:@"option[selected]"];
            NSString *selectedPageValue = selectedOption[@"value"];
            currentPage = (int32_t)selectedPageValue.integerValue;
        } else {
            numberOfPages = 1;
            currentPage = 1;
        }
    }
    if (singleUser) {
        [thread setNumberOfPages:numberOfPages forSingleUser:singleUser];
    } else {
        thread.numberOfPages = numberOfPages;
    }
    HTMLElement *bookmarkButton = [body awful_firstNodeMatchingCachedSelector:@"div.threadbar img.thread_bookmark"];
    if (bookmarkButton) {
        NSArray *bookmarkClasses = [bookmarkButton[@"class"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([bookmarkClasses containsObject:@"unbookmark"] && thread.starCategory == AwfulStarCategoryNone) {
            thread.starCategory = AwfulStarCategoryOrange;
        } else if ([bookmarkClasses containsObject:@"bookmark"] && thread.starCategory != AwfulStarCategoryNone) {
            thread.starCategory = AwfulStarCategoryNone;
        }
    }
    
    // TODO scrape ad
    
    NSMutableArray *posts = [NSMutableArray new];
    NSArray *postTables = [document awful_nodesMatchingCachedSelector:@"table.post"];
    __block AwfulPost *firstUnseenPost;
    [postTables enumerateObjectsUsingBlock:^(HTMLElement *table, NSUInteger i, BOOL *stop) {
        NSString *postID;
        {
            AwfulScanner *scanner = [AwfulScanner scannerWithString:table[@"id"]];
            [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
            postID = [scanner.string substringFromIndex:scanner.scanLocation];
        }
        if (postID.length == 0) {
            if (error) {
                *error = [NSError errorWithDomain:AwfulErrorDomain
                                             code:AwfulErrorCodes.parseError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Post parsing failed; could not find post ID" }];
            }
            return;
        }
        AwfulPost *post = [AwfulPost firstOrNewPostWithPostID:postID inManagedObjectContext:managedObjectContext];
        [posts addObject:post];
        post.thread = thread;
        int32_t index = (currentPage - 1) * 40 + (int32_t)i + 1;
        NSInteger indexAttribute = [table[@"data-idx"] integerValue];
        if (indexAttribute > 0) {
            index = (int32_t)indexAttribute;
        }
        if (index > 0) {
            if (singleUser) {
                post.singleUserIndex = index;
            } else {
                post.threadIndex = index;
            }
        }
        HTMLElement *postDateCell = [table awful_firstNodeMatchingCachedSelector:@"td.postdate"];
        if (postDateCell) {
            HTMLTextNode *postDateText = postDateCell.children.lastObject;
            NSString *postDateString = [postDateText.data stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            post.postDate = [self.postDateParser dateFromString:postDateString];
        }
        AwfulUser *author = [self.authorScraper scrapeAuthorFromNode:table intoManagedObjectContext:managedObjectContext];
        if (author) {
            post.author = author;
            if ([table awful_firstNodeMatchingCachedSelector:@"dt.author.op"]) {
                thread.author = author;
            }
        }
        HTMLElement *privateMessageLink = [table awful_firstNodeMatchingCachedSelector:@"ul.profilelinks a[href *= 'private.php']"];
        author.canReceivePrivateMessages = !!privateMessageLink;
        HTMLElement *editButton = [table awful_firstNodeMatchingCachedSelector:@"ul.postbuttons a[href *= 'editpost.php']"];
        post.editable = !!editButton;
        HTMLElement *seenRow = [table awful_firstNodeMatchingCachedSelector:@"tr.seen1"] ?: [table awful_firstNodeMatchingCachedSelector:@"tr.seen2"];
        if (!seenRow && !firstUnseenPost) {
            firstUnseenPost = post;
        }
        HTMLElement *postBodyElement = [table awful_firstNodeMatchingCachedSelector:@"div.complete_shit"] ?: [table awful_firstNodeMatchingCachedSelector:@"td.postbody"];
        if (postBodyElement) {
            post.innerHTML = postBodyElement.innerHTML;
        }
    }];
    if (firstUnseenPost && !singleUser) {
        thread.seenPosts = firstUnseenPost.threadIndex - 1;
    }
    if (numberOfPages > 0 && currentPage == numberOfPages && !singleUser) {
        AwfulPost *lastPost = posts.lastObject;
        thread.lastPostDate = lastPost.postDate;
        thread.lastPostAuthorName = lastPost.author.username;
    }
    [managedObjectContext save:error];
    return posts;
}

@end
