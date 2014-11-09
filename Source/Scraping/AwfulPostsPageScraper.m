//  AwfulPostsPageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsPageScraper.h"
#import "AuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulModels.h"
#import "AwfulScanner.h"
#import "AwfulStarCategory.h"
#import "HTMLNode+CachedSelector.h"
#import <HTMLReader/HTMLTextNode.h>
#import "NSURL+QueryDictionary.h"
#import "Awful-Swift.h"

@interface AwfulPostsPageScraper ()

@property (strong, nonatomic) Thread *thread;

@property (copy, nonatomic) NSArray *posts;

@property (copy, nonatomic) NSString *advertisementHTML;

@end

@implementation AwfulPostsPageScraper

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
    HTMLElement *body = [self.node awful_firstNodeMatchingCachedSelector:@"body"];
    self.thread = [Thread firstOrNewThreadWithID:body[@"data-thread"] inManagedObjectContext:self.managedObjectContext];
    Forum *forum = [Forum fetchOrInsertForumInManagedObjectContext:self.managedObjectContext withID:body[@"data-forum"]];
    self.thread.forum = forum;
    
    if (!self.thread.threadID && [body awful_firstNodeMatchingCachedSelector:@"div.standard div.inner a[href*=archives.php]"]) {
        self.error = [NSError errorWithDomain:AwfulErrorDomain
                                         code:AwfulErrorCodes.archivesRequired
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Viewing this content requires the archives upgrade." }];
        return;
    }
    
    HTMLElement *breadcrumbsDiv = [body awful_firstNodeMatchingCachedSelector:@"div.breadcrumbs"];
    
    // Last hierarchy link is the thread.
    // First hierarchy link is the category.
    // Intervening hierarchy links are forums/subforums.
    NSArray *hierarchyLinks = [breadcrumbsDiv awful_nodesMatchingCachedSelector:@"a[href *= 'id=']"];
    
    HTMLElement *threadLink = hierarchyLinks.lastObject;
    self.thread.title = threadLink.textContent;
    if (hierarchyLinks.count > 1) {
        HTMLElement *categoryLink = hierarchyLinks.firstObject;
        NSURL *URL = [NSURL URLWithString:categoryLink[@"href"]];
        NSString *categoryID = URL.queryDictionary[@"forumid"];
        AwfulCategory *category = [AwfulCategory firstOrNewCategoryWithCategoryID:categoryID inManagedObjectContext:self.managedObjectContext];
        category.name = categoryLink.textContent;
        NSArray *subforumLinks = [hierarchyLinks subarrayWithRange:NSMakeRange(1, hierarchyLinks.count - 2)];
        Forum *currentForum;
        for (HTMLElement *subforumLink in subforumLinks.reverseObjectEnumerator) {
            NSURL *URL = [NSURL URLWithString:subforumLink[@"href"]];
            NSString *subforumID = URL.queryDictionary[@"forumid"];
            Forum *subforum = [Forum fetchOrInsertForumInManagedObjectContext:self.managedObjectContext withID:subforumID];
            subforum.name = subforumLink.textContent;
            subforum.category = category;
            currentForum.parentForum = subforum;
            currentForum = subforum;
        }
    }
    
    HTMLElement *closedImage = [body awful_firstNodeMatchingCachedSelector:@"ul.postbuttons a[href *= 'newreply'] img[src *= 'closed']"];
    self.thread.closed = !!closedImage;
    
    BOOL singleUserFilterEnabled = !![self.node awful_firstNodeMatchingCachedSelector:@"table.post a.user_jump[title *= 'Remove']"];
    
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
    
    HTMLElement *bookmarkButton = [body awful_firstNodeMatchingCachedSelector:@"div.threadbar img.thread_bookmark"];
    if (bookmarkButton) {
        NSArray *bookmarkClasses = [bookmarkButton[@"class"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([bookmarkClasses containsObject:@"unbookmark"] && self.thread.starCategory == AwfulStarCategoryNone) {
            self.thread.starCategory = AwfulStarCategoryOrange;
        } else if ([bookmarkClasses containsObject:@"bookmark"] && self.thread.starCategory != AwfulStarCategoryNone) {
            self.thread.starCategory = AwfulStarCategoryNone;
        }
    }
    
    self.advertisementHTML = [[self.node awful_firstNodeMatchingCachedSelector:@"#ad_banner_user a"] serializedFragment];
    
    NSArray *postTables = [self.node awful_nodesMatchingCachedSelector:@"table.post"];
    NSMutableArray *postIDs = [NSMutableArray new];
    NSMutableArray *userIDs = [NSMutableArray new];
    NSMutableArray *usernames = [NSMutableArray new];
    NSMutableArray *authorScrapers = [NSMutableArray new];
    for (HTMLElement *table in postTables) {
        AwfulScanner *scanner = [AwfulScanner scannerWithString:table[@"id"]];
        [scanner scanUpToCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:nil];
        NSString *postID = [scanner.string substringFromIndex:scanner.scanLocation];
        if (postID.length == 0) {
            NSString *message = @"Post parsing failed; could not find post ID";
            self.error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.parseError userInfo:@{ NSLocalizedDescriptionKey: message }];
            return;
        }
        [postIDs addObject:postID];
        
        AuthorScraper *authorScraper = [AuthorScraper scrapeNode:table intoManagedObjectContext:self.managedObjectContext];
        [authorScrapers addObject:authorScraper];
        if (authorScraper.userID) {
            [userIDs addObject:authorScraper.userID];
        }
        if (authorScraper.username) {
            [usernames addObject:authorScraper.username];
        }
    }
    NSDictionary *fetchedPosts = [Post dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                       keyedByAttributeNamed:@"postID"
                                                     matchingPredicateFormat:@"postID IN %@", postIDs];
    NSMutableDictionary *usersByID = [[User dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                            keyedByAttributeNamed:@"userID"
                                                          matchingPredicateFormat:@"userID IN %@", userIDs] mutableCopy];
    NSMutableDictionary *usersByName = [[User dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                              keyedByAttributeNamed:@"username"
                                                            matchingPredicateFormat:@"userID = nil AND username IN %@", usernames] mutableCopy];
    
    NSMutableArray *posts = [NSMutableArray new];
    __block Post *firstUnseenPost;
    [postTables enumerateObjectsUsingBlock:^(HTMLElement *table, NSUInteger i, BOOL *stop) {
        NSString *postID = postIDs[i];
        Post *post = fetchedPosts[postID];
        if (!post) {
            post = [Post insertInManagedObjectContext:self.managedObjectContext];
            post.postID = postID;
        }
        [posts addObject:post];
        
        post.thread = self.thread;
        
        {{
            int32_t index = (currentPage - 1) * 40 + (int32_t)i + 1;
            NSInteger indexAttribute = [table[@"data-idx"] integerValue];
            if (indexAttribute > 0) {
                index = (int32_t)indexAttribute;
            }
            if (index > 0) {
                if (singleUserFilterEnabled) {
                    post.filteredThreadIndex = index;
                } else {
                    post.threadIndex = index;
                }
            }
        }}
        
        {{
            post.ignored = [table hasClass:@"ignored"];
        }}
        
        {{
            HTMLElement *postDateCell = [table awful_firstNodeMatchingCachedSelector:@"td.postdate"];
            if (postDateCell) {
                HTMLTextNode *postDateText = postDateCell.children.lastObject;
                NSString *postDateString = [postDateText.data stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                post.postDate = [[AwfulCompoundDateParser postDateParser] dateFromString:postDateString];
            }
        }}
        
        {{
            AuthorScraper *authorScraper = authorScrapers[i];
            User *author;
            if (authorScraper.userID) {
                author = usersByID[authorScraper.userID];
            } else if (authorScraper.username) {
                author = usersByName[authorScraper.username];
            }
            if (author) {
                authorScraper.author = author;
            } else {
                author = authorScraper.author;
            }
            if (author) {
                post.author = author;
                if ([table awful_firstNodeMatchingCachedSelector:@"dt.author.op"]) {
                    self.thread.author = post.author;
                }
                HTMLElement *privateMessageLink = [table awful_firstNodeMatchingCachedSelector:@"ul.profilelinks a[href*='private.php']"];
                post.author.canReceivePrivateMessages = !!privateMessageLink;
                if (author.userID) {
                    usersByID[author.userID] = author;
                }
                if (author.username) {
                    usersByName[author.username] = author;
                }
            }
        }}
        
        {{
            HTMLElement *editButton = [table awful_firstNodeMatchingCachedSelector:@"ul.postbuttons a[href*='editpost.php']"];
            post.editable = !!editButton;
        }}
        
        {{
            HTMLElement *seenRow = [table awful_firstNodeMatchingCachedSelector:@"tr.seen1"] ?: [table awful_firstNodeMatchingCachedSelector:@"tr.seen2"];
            if (!seenRow && !firstUnseenPost) {
                firstUnseenPost = post;
            }
        }}
        
        {{
            HTMLElement *postBodyElement = ([table awful_firstNodeMatchingCachedSelector:@"div.complete_shit"] ?:
                                            [table awful_firstNodeMatchingCachedSelector:@"td.postbody"]);
            if (postBodyElement) {
                if (post.innerHTML.length == 0 || !post.ignored) {
                    post.innerHTML = postBodyElement.innerHTML;
                }
            }
        }}
    }];
    self.posts = posts;
    
    if (firstUnseenPost && !singleUserFilterEnabled) {
        self.thread.seenPosts = firstUnseenPost.threadIndex - 1;
    }
    
    Post *lastPost = posts.lastObject;
    if (numberOfPages > 0 && currentPage == numberOfPages && !singleUserFilterEnabled) {
        self.thread.lastPostDate = lastPost.postDate;
        self.thread.lastPostAuthorName = lastPost.author.username;
    }
    
    if (singleUserFilterEnabled) {
        [self.thread setFilteredNumberOfPages:numberOfPages forAuthor:lastPost.author];
    } else {
        self.thread.numberOfPages = numberOfPages;
    }
}

@end
