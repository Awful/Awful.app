//  AwfulPostsPageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsPageScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulModels.h"
#import "AwfulScanner.h"
#import "GTMNSString+HTML.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulPostsPageScraper ()

@property (strong, nonatomic) AwfulCompoundDateParser *postDateParser;
@property (strong, nonatomic) AwfulCompoundDateParser *regdateDateParser;

@end

@implementation AwfulPostsPageScraper

- (AwfulCompoundDateParser *)postDateParser
{
    if (!_postDateParser) _postDateParser = [AwfulCompoundDateParser postDateParser];
    return _postDateParser;
}

- (AwfulCompoundDateParser *)regdateDateParser
{
    if (!_regdateDateParser) _regdateDateParser = [AwfulCompoundDateParser regdateDateParser];
    return _regdateDateParser;
}

#pragma mark - AwfulDocumentScraper

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError **)error
{
    AwfulThread *thread;
    AwfulForum *forum;
    HTMLElementNode *body = [document firstNodeMatchingSelector:@"body"];
    thread = [AwfulThread firstOrNewThreadWithThreadID:body[@"data-thread"] inManagedObjectContext:managedObjectContext];
    forum = [AwfulForum fetchOrInsertForumInManagedObjectContext:managedObjectContext withID:body[@"data-forum"]];
    thread.forum = forum;
    
    HTMLElementNode *breadcrumbsDiv = [body firstNodeMatchingSelector:@"div.breadcrumbs"];
    
    // Last hierarchy link is the thread.
    // First hierarchy link is the category.
    // Intervening hierarchy links are forums/subforums.
    NSArray *hierarchyLinks = [breadcrumbsDiv nodesMatchingSelector:@"a[href *= 'id=']"];
    
    HTMLElementNode *threadLink = hierarchyLinks.lastObject;
    thread.title = [threadLink.innerHTML gtm_stringByUnescapingFromHTML];
    if (hierarchyLinks.count > 1) {
        HTMLElementNode *categoryLink = hierarchyLinks.firstObject;
        NSURL *URL = [NSURL URLWithString:categoryLink[@"href"]];
        NSString *categoryID = URL.queryDictionary[@"forumid"];
        AwfulCategory *category = [AwfulCategory firstOrNewCategoryWithCategoryID:categoryID
                                                           inManagedObjectContext:managedObjectContext];
        category.name = [categoryLink.innerHTML gtm_stringByUnescapingFromHTML];
        NSArray *subforumLinks = [hierarchyLinks subarrayWithRange:NSMakeRange(1, hierarchyLinks.count - 2)];
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
    
    HTMLElementNode *closedImage = [body firstNodeMatchingSelector:@"ul.postbuttons a[href *= 'newreply'] img[src *= 'closed']"];
    thread.closed = !!closedImage;
    
    NSString *singleUserID = documentURL.queryDictionary[@"userid"];
    AwfulUser *singleUser;
    if (singleUserID) {
        singleUser = [AwfulUser firstOrNewUserWithUserID:singleUserID username:nil inManagedObjectContext:managedObjectContext];
    }
    
    HTMLElementNode *pagesDiv = [body firstNodeMatchingSelector:@"div.pages"];
    HTMLElementNode *pagesSelect = [pagesDiv firstNodeMatchingSelector:@"select"];
    int32_t numberOfPages = 0;
    if (pagesDiv) {
        if (pagesSelect) {
            HTMLElementNode *lastOption = [pagesSelect nodesMatchingSelector:@"option"].lastObject;
            NSString *pageValue = lastOption[@"value"];
            numberOfPages = (int32_t)pageValue.integerValue;
        } else {
            numberOfPages = 1;
        }
    }
    if (singleUser) {
        [thread setNumberOfPages:numberOfPages forSingleUser:singleUser];
    } else {
        thread.numberOfPages = numberOfPages;
    }
    HTMLElementNode *bookmarkButton = [body firstNodeMatchingSelector:@"div.threadbar img.thread_bookmark"];
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
    NSArray *postTables = [document nodesMatchingSelector:@"table.post"];
    AwfulPost *firstUnseenPost;
    for (HTMLElementNode *table in postTables) {
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
            continue;
        }
        AwfulPost *post = [AwfulPost firstOrNewPostWithPostID:postID inManagedObjectContext:managedObjectContext];
        [posts addObject:post];
        post.thread = thread;
        int32_t index = (int32_t)[table[@"data-idx"] integerValue];
        if (index > 0) {
            if (singleUser) {
                post.singleUserIndex = index;
            } else {
                post.threadIndex = index;
            }
        }
        HTMLElementNode *postDateCell = [table firstNodeMatchingSelector:@"td.postdate"];
        if (postDateCell) {
            HTMLTextNode *postDateText = postDateCell.childNodes.lastObject;
            NSString *postDateString = [postDateText.data stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            post.postDate = [self.postDateParser dateFromString:postDateString];
        }
        HTMLElementNode *authorTerm = [table firstNodeMatchingSelector:@"dt.author"];
        HTMLElementNode *authorUserIDLink = [table firstNodeMatchingSelector:@"ul.profilelinks a[href *= 'userid']"];
        NSString *authorUsername = [authorTerm.innerHTML gtm_stringByUnescapingFromHTML];
        NSString *authorUserID;
        {
            NSURL *URL = [NSURL URLWithString:authorUserIDLink[@"href"]];
            authorUserID = URL.queryDictionary[@"userid"];
        }
        AwfulUser *author = [AwfulUser firstOrNewUserWithUserID:authorUserID
                                                       username:authorUsername
                                         inManagedObjectContext:managedObjectContext];
        post.author = author;
        NSArray *authorClasses = [authorTerm[@"class"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (authorClasses) {
            author.administrator = [authorClasses containsObject:@"role-admin"];
            author.moderator = [authorClasses containsObject:@"role-mod"];
            if ([authorClasses containsObject:@"op"]) {
                thread.author = author;
            }
        }
        HTMLElementNode *regdateDefinition = [table firstNodeMatchingSelector:@"dd.registered"];
        if (regdateDefinition) {
            author.regdate = [self.regdateDateParser dateFromString:[regdateDefinition.innerHTML gtm_stringByUnescapingFromHTML]];
        }
        HTMLElementNode *customTitleDefinition = [table firstNodeMatchingSelector:@"dl.userinfo dd.title"];
        if (customTitleDefinition) {
            author.customTitleHTML = customTitleDefinition.innerHTML;
        }
        HTMLElementNode *privateMessageLink = [table firstNodeMatchingSelector:@"ul.profilelinks a[href *= 'private.php']"];
        author.canReceivePrivateMessages = !!privateMessageLink;
        HTMLElementNode *editButton = [table firstNodeMatchingSelector:@"ul.postbuttons a[href *= 'editpost.php']"];
        post.editable = !!editButton;
        HTMLElementNode *seenRow = [table firstNodeMatchingSelector:@"tr.seen1"] ?: [table firstNodeMatchingSelector:@"tr.seen2"];
        if (!seenRow && !firstUnseenPost) {
            firstUnseenPost = post;
        }
        HTMLElementNode *postBodyElement = [table firstNodeMatchingSelector:@"div.complete_shit"] ?: [table firstNodeMatchingSelector:@"td.postbody"];
        if (postBodyElement) {
            post.innerHTML = postBodyElement.innerHTML;
        }
    }
    if (firstUnseenPost && !singleUser) {
        thread.seenPosts = firstUnseenPost.threadIndex - 1;
    }
    [managedObjectContext save:error];
    return posts;
}

@end
