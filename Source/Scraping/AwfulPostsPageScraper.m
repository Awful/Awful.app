//  AwfulPostsPageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsPageScraper.h"
#import "AuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulScanner.h"
#import "AwfulStarCategory.h"
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
    
    HTMLElement *body = [self.node firstNodeMatchingSelector:@"body"];
    ThreadKey *threadKey = [[ThreadKey alloc] initWithThreadID:body[@"data-thread"]];
    self.thread = [Thread objectForKey:threadKey inManagedObjectContext:self.managedObjectContext];
    ForumKey *forumKey = [[ForumKey alloc] initWithForumID:body[@"data-forum"]];
    Forum *forum = [Forum objectForKey:forumKey inManagedObjectContext:self.managedObjectContext];
    self.thread.forum = forum;
    
    if (!self.thread.threadID && [body firstNodeMatchingSelector:@"div.standard div.inner a[href*=archives.php]"]) {
        self.error = [NSError errorWithDomain:AwfulErrorDomain
                                         code:AwfulErrorCodes.archivesRequired
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Viewing this content requires the archives upgrade." }];
        return;
    }
    
    HTMLElement *breadcrumbsDiv = [body firstNodeMatchingSelector:@"div.breadcrumbs"];
    
    // Last hierarchy link is the thread.
    // First hierarchy link is the category.
    // Intervening hierarchy links are forums/subforums.
    NSArray *hierarchyLinks = [breadcrumbsDiv nodesMatchingSelector:@"a[href *= 'id=']"];
    
    HTMLElement *threadLink = hierarchyLinks.lastObject;
    self.thread.title = threadLink.textContent;
    if (hierarchyLinks.count > 1) {
        HTMLElement *groupLink = hierarchyLinks.firstObject;
        NSURL *URL = [NSURL URLWithString:groupLink[@"href"]];
        ForumGroupKey *groupKey = [[ForumGroupKey alloc] initWithGroupID:URL.queryDictionary[@"forumid"]];
        ForumGroup *group = [ForumGroup objectForKey:groupKey inManagedObjectContext:self.managedObjectContext];
        group.name = groupLink.textContent;
        NSArray *subforumLinks = [hierarchyLinks subarrayWithRange:NSMakeRange(1, hierarchyLinks.count - 2)];
        Forum *currentForum;
        for (HTMLElement *subforumLink in subforumLinks.reverseObjectEnumerator) {
            NSURL *URL = [NSURL URLWithString:subforumLink[@"href"]];
            ForumKey *subforumKey = [[ForumKey alloc] initWithForumID:URL.queryDictionary[@"forumid"]];
            Forum *subforum = [Forum objectForKey:subforumKey inManagedObjectContext:self.managedObjectContext];
            subforum.name = subforumLink.textContent;
            subforum.group = group;
            currentForum.parentForum = subforum;
            currentForum = subforum;
        }
    }
    
    HTMLElement *closedImage = [body firstNodeMatchingSelector:@"ul.postbuttons a[href *= 'newreply'] img[src *= 'closed']"];
    self.thread.closed = !!closedImage;
    
    BOOL singleUserFilterEnabled = !![self.node firstNodeMatchingSelector:@"table.post a.user_jump[title *= 'Remove']"];
    
    HTMLElement *pagesDiv = [body firstNodeMatchingSelector:@"div.pages"];
    HTMLElement *pagesSelect = [pagesDiv firstNodeMatchingSelector:@"select"];
    int32_t numberOfPages = 0;
    int32_t currentPage = 0;
    if (pagesDiv) {
        if (pagesSelect) {
            HTMLElement *lastOption = [pagesSelect nodesMatchingSelector:@"option"].lastObject;
            NSString *pageValue = lastOption[@"value"];
            numberOfPages = (int32_t)pageValue.integerValue;
            HTMLElement *selectedOption = [pagesSelect firstNodeMatchingSelector:@"option[selected]"];
            NSString *selectedPageValue = selectedOption[@"value"];
            currentPage = (int32_t)selectedPageValue.integerValue;
        } else {
            numberOfPages = 1;
            currentPage = 1;
        }
    }
    
    HTMLElement *bookmarkButton = [body firstNodeMatchingSelector:@"div.threadbar img.thread_bookmark"];
    if (bookmarkButton) {
        NSArray *bookmarkClasses = [bookmarkButton[@"class"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([bookmarkClasses containsObject:@"unbookmark"] && self.thread.starCategory == AwfulStarCategoryNone) {
            self.thread.starCategory = AwfulStarCategoryOrange;
        } else if ([bookmarkClasses containsObject:@"bookmark"] && self.thread.starCategory != AwfulStarCategoryNone) {
            self.thread.starCategory = AwfulStarCategoryNone;
        }
    }
    
    self.advertisementHTML = [[self.node firstNodeMatchingSelector:@"#ad_banner_user a"] serializedFragment];
    
    NSArray *postTables = [self.node nodesMatchingSelector:@"table.post"];
    NSMutableArray *postKeys = [NSMutableArray new];
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
        [postKeys addObject:[[PostKey alloc] initWithPostID:postID]];
        
        AuthorScraper *authorScraper = [AuthorScraper scrapeNode:table intoManagedObjectContext:self.managedObjectContext];
        [authorScrapers addObject:authorScraper];
    }
    NSArray *posts = [Post objectsForKeys:postKeys inManagedObjectContext:self.managedObjectContext];
    
    NSMutableArray *userKeys = [NSMutableArray new];
    for (AuthorScraper *authorScraper in authorScrapers) {
        if (!authorScraper.error) {
            [userKeys addObject:[[UserKey alloc] initWithUserID:authorScraper.userID username:authorScraper.username]];
        }
    }
    NSArray *users = [User objectsForKeys:userKeys inManagedObjectContext:self.managedObjectContext];
    NSDictionary *usersByKey = [NSDictionary dictionaryWithObjects:users forKeys:[users valueForKey:@"objectKey"]];
    
    __block Post *firstUnseenPost;
    [postTables enumerateObjectsUsingBlock:^(HTMLElement *table, NSUInteger i, BOOL *stop) {
        Post *post = posts[i];
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
            HTMLElement *postDateCell = [table firstNodeMatchingSelector:@"td.postdate"];
            if (postDateCell) {
                HTMLNode *postDateText = postDateCell.children.lastObject;
                NSString *postDateString = [postDateText.textContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                post.postDate = [[AwfulCompoundDateParser postDateParser] dateFromString:postDateString];
            }
        }}
        
        {{
            UserKey *authorKey;
            AuthorScraper *authorScraper = authorScrapers[i];
            if (!authorScraper.error) {
                authorKey = [[UserKey alloc] initWithUserID:authorScraper.userID username:authorScraper.username];
            }
            if (authorKey) {
                User *author = usersByKey[authorKey];
                post.author = author;
                authorScraper.author = author;
                HTMLElement *privateMessageLink = [table firstNodeMatchingSelector:@"ul.profilelinks a[href*='private.php']"];
                author.canReceivePrivateMessages = !!privateMessageLink;
                if ([table firstNodeMatchingSelector:@"dt.author.op"]) {
                    self.thread.author = author;
                }
            }
        }}
        
        {{
            HTMLElement *editButton = [table firstNodeMatchingSelector:@"ul.postbuttons a[href*='editpost.php']"];
            post.editable = !!editButton;
        }}
        
        {{
            HTMLElement *seenRow = [table firstNodeMatchingSelector:@"tr.seen1"] ?: [table firstNodeMatchingSelector:@"tr.seen2"];
            if (!seenRow && !firstUnseenPost) {
                firstUnseenPost = post;
            }
        }}
        
        {{
            HTMLElement *postBodyElement = ([table firstNodeMatchingSelector:@"div.complete_shit"] ?:
                                            [table firstNodeMatchingSelector:@"td.postbody"]);
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
