//
//  AwfulPageDataController.m
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageDataController.h"
#import "TFHpple.h"
#import "TFHppleElement.h"
#import "XPathQuery.h"
#import "AwfulPageTemplate.h"
#import "AwfulStringEncoding.h"

@interface AwfulPageDataController ()

@property (readonly, nonatomic) AwfulPageTemplate *template;

@end

@implementation AwfulPageDataController

@synthesize threadTitle = _threadTitle;
@synthesize forum = _forum;
@synthesize currentPage = _currentPage;
@synthesize numberOfPages = _numberOfPages;
@synthesize posts = _posts;
@synthesize newestPostIndex = _newestPostIndex;
@synthesize userAd = _userAd;
@synthesize bookmarked = _bookmarked;

- (id)initWithResponseData:(NSData *)responseData pageURL:(NSURL *)pageURL
{
    self = [super init];
    if (self) {
        NSString *raw = [[NSString alloc] initWithData:responseData encoding:NSWindowsCP1252StringEncoding];
        NSAssert(!raw || [raw rangeOfString:@"<size:"].location == NSNotFound, @"found <size:", nil);
//        NSString *filtered = [raw stringByReplacingOccurrencesOfString:@"<size:" withString:@"<"];
        NSData *converted = [StringFromSomethingAwfulData(responseData) dataUsingEncoding:NSUTF8StringEncoding];
        TFHpple *pageParser = [[TFHpple alloc] initWithHTMLData:converted];
        _threadTitle = ParseThreadTitle(pageParser);
        _forum = ParseForum(pageParser);
        _numberOfPages = ParsePageCount(pageParser, &_currentPage);
        _posts = ParsePosts(pageParser, _forum.forumID);
        _newestPostIndex = ParseNewPostIndex(pageURL);
        _userAd = ParseUserAdHTML(pageParser);
        _bookmarked = ParseBookmarked(pageParser);
    }
    return self;
}

static NSString *ParseThreadTitle(TFHpple *parser)
{
    TFHppleElement *title = [parser searchForSingle:@"//a[@class='bclast']"];
    return title ? [title content] : @"Title Not Found";
}

static AwfulForum *ParseForum(TFHpple *parser)
{
    NSArray *breadcrumbs = [parser search:@"//div[@class='breadcrumbs']//a"];
    NSString *lastForumID = nil;
    for (TFHppleElement *element in breadcrumbs) {
        NSString *src = [element objectForKey:@"href"];
        NSRange range = [src rangeOfString:@"forumdisplay.php"];
        if (range.location != NSNotFound) {
            NSArray *split = [src componentsSeparatedByString:@"="];
            lastForumID = [split lastObject];
        }
    }
    
    if (!lastForumID) {
        return nil;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AwfulForum"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"forumID=%@", lastForumID];
    [fetchRequest setPredicate:predicate];
    
    NSError *err = nil;
    NSArray *results = [ApplicationDelegate.managedObjectContext executeFetchRequest:fetchRequest
                                                                               error:&err];
    if (!results) {
        NSLog(@"couldn't fetch forum from forumid %@", [err localizedDescription]);
        return nil;
    }
    
    return [results count] > 0 ? [results lastObject] : nil;
}

static NSInteger ParsePageCount(TFHpple *parser, NSInteger *currentPage)
{
    NSArray *strings = PerformRawHTMLXPathQuery(parser.data, @"//div[@class='pages top']");
    if ([strings count] == 0) {
        *currentPage = 1;
        return 1;
    }
    
    // this is going to get me in trouble one day
    NSString *pageInfo = [strings objectAtIndex:0];
    NSRange firstParen = [pageInfo rangeOfString:@"("];
    if (firstParen.location == NSNotFound) {
        *currentPage = 1;
        return 1;
    }
    
    NSRange last_paren = [pageInfo rangeOfString:@")"];
    NSRange combined;
    combined.location = firstParen.location + 1;
    combined.length = last_paren.location - firstParen.location - 1;
    NSString *totalPagesString = [pageInfo substringWithRange:combined];
    
    TFHpple *base = [[TFHpple alloc] initWithHTMLData:[pageInfo dataUsingEncoding:NSUTF8StringEncoding]];
    TFHppleElement *curpage = [base searchForSingle:@"//span[@class='curpage']"];
    if (curpage) {
        *currentPage = [[curpage content] intValue];
    }
    return [totalPagesString intValue];
}

static AwfulPost *ParsePost(TFHpple *parser, NSString *forumID);

static NSMutableArray *ParsePosts(TFHpple *parser, NSString *forumID)
{
    NSArray *postStrings = PerformRawHTMLXPathQuery(parser.data, @"//table[@class='post']|//table[@class='post ignored']");
    NSMutableArray *parsedPosts = [[NSMutableArray alloc] init];
    for (NSString *postHTML in postStrings) @autoreleasepool {
        TFHpple *postBase = [[TFHpple alloc] initWithHTMLData:[postHTML dataUsingEncoding:NSUTF8StringEncoding]];
        AwfulPost *post = ParsePost(postBase, forumID);
        post.postIndex = [postStrings indexOfObject:postHTML];
        [parsedPosts addObject:post];
    }
    return parsedPosts;
}

static AwfulPost *ParsePost(TFHpple *parser, NSString *forumID)
{
    AwfulPost *post = [[AwfulPost alloc] init];
    
    NSString *username_search = @"//dt[@class='author']|//dt[@class='author op']|//dt[@class='author role-mod']|//dt[@class='author role-admin']|//dt[@class='author role-mod op']|//dt[@class='author role-admin op']";
    
    TFHppleElement *author = [parser searchForSingle:username_search];
    if(author != nil) {
        post.posterName = [author content];
        NSString *author_class = [author objectForKey:@"class"];
        if([author_class isEqualToString:@"author op"] || [author_class isEqualToString:@"author role-admin op"] || [author_class isEqualToString:@"author role-mod op"]) {
            post.isOP = YES;
        } else {
            post.isOP = NO;
        }
        
        TFHppleElement *mod = [parser searchForSingle:@"//dt[@class='author role-mod']|//dt[@class='author role-mod op']"];
        if(mod != nil) {
            post.posterType = AwfulUserTypeMod;
        }
        
        TFHppleElement *admin = [parser searchForSingle:@"//dt[@class='author role-admin']|//dt[@class='author role-admin op']"];
        if(admin != nil) {
            post.posterType = AwfulUserTypeAdmin;
        }
        
        if([parser searchForSingle:@"//img[@alt='Edit']"]) {
            post.canEdit = YES;
        }
    }
    
    TFHppleElement *post_id = [parser searchForSingle:@"//table[@class='post']|//table[@class='post ignored']"];
    if(post_id != nil) {
        NSString *post_id_str = [post_id objectForKey:@"id"];
        post.postID = [post_id_str substringFromIndex:4];
    }
    
    TFHppleElement *post_date = [parser searchForSingle:@"//td[@class='postdate']"];
    if(post_date != nil) {
        post.postDate = [post_date content];
    }
    
    TFHppleElement *seen_link = [parser searchForSingle:@"//td[@class='postdate']//a[@title='Mark thread seen up to this post']"];
    if(seen_link != nil) {
        post.markSeenLink = [seen_link objectForKey:@"href"];
    }
    
    TFHppleElement *avatar = [parser searchForSingle:@"//dd[@class='title']//img"];
    if(avatar != nil) {
        post.avatarURL = [NSURL URLWithString:[avatar objectForKey:@"src"]];
    }
    
    TFHppleElement *edited = [parser searchForSingle:@"//p[@class='editedby']/span"];
    if(edited != nil) {
        post.editedStr = [[edited content] stringByReplacingOccurrencesOfString:@"fucked around with this message" withString:@"edited"];
    }
    
    NSString *body_search_str = @"//td[@class='postbody']";
    if([forumID isEqualToString:@"26"]) {
        body_search_str = @"//div[@class='complete_shit funbox']";
    }
    
    NSArray *body_strings = [parser rawSearch:body_search_str];
    
    if([body_strings count] == 1) {
        NSMutableString *post_body = [[body_strings objectAtIndex:0] mutableCopy];
        
        // Fix some bullshit from libxml and WebKit teaming up to wreck our day.
        // libxml sees '<b></b>' and shits out '<b/>', which UIWebView interprets as '<b>', turning
        // everything bold. Ditto for italic or whatever else we feel like messing with.
        [post_body replaceOccurrencesOfString:@"<b/>"
                                   withString:@"<b></b>"
                                      options:NSCaseInsensitiveSearch
                                        range:NSMakeRange(0, post_body.length)];
        [post_body replaceOccurrencesOfString:@"<i/>"
                                   withString:@"<i></i>"
                                      options:NSCaseInsensitiveSearch
                                        range:NSMakeRange(0, post_body.length)];
        [post_body replaceOccurrencesOfString:@"<s/>"
                                   withString:@"<s></s>"
                                      options:NSCaseInsensitiveSearch
                                        range:NSMakeRange(0, post_body.length)];

        post.postBody = post_body;
        
        TFHppleElement *seen = [parser searchForSingle:@"//tr[@class='seen1']|//tr[@class='seen2']"];
        post.seen = (seen != nil);
    }
    
    return post;
}

static NSUInteger ParseNewPostIndex(NSURL *pageURL)
{
    NSString *frag = [pageURL fragment];
    if (!frag) {
        return 0;
    }
    NSRange r = [frag rangeOfString:@"pti"];
    if (r.location != 0) {
        return 0;
    }
    NSString *new_post = [frag stringByReplacingOccurrencesOfString:@"pti" withString:@""];
    return [new_post integerValue] - 1;
}

static NSString *ParseUserAdHTML(TFHpple *parser)
{
    NSArray *raws = [parser rawSearch:@"//div[@id='ad_banner_user']/a"];
    return [raws count] > 0 ? [raws objectAtIndex:0] : @"";
}

static BOOL ParseBookmarked(TFHpple *parser)
{
    TFHppleElement *markButton = [parser searchForSingle:@"//img[@id='button_bookmark']"];
    return [[markButton.attributes objectForKey:@"class"] isEqualToString:@"unbookmark"];
}

@synthesize template = _template;

- (AwfulPageTemplate *)template
{
    if (!_template) {
        _template = [[AwfulPageTemplate alloc] init];
    }
    return _template;
}

-(NSString *)constructedPageHTML
{
    return [self.template renderWithPageDataController:self];
}

-(NSString *)constructedPageHTMLWithAllPosts
{
    return [self.template renderWithPageDataController:self displayAllPosts:YES];
}

-(NSString *)calculatePostIDScrollDestination
{    
    if(self.newestPostIndex < [self.posts count]) {
        AwfulPost *post = [self.posts objectAtIndex:self.newestPostIndex];
        return post.postID;
    }
    return nil;
}

-(BOOL)shouldScrollToBottom
{
    return self.newestPostIndex == [self.posts count];
}

-(int)numNewPostsLoaded
{
    return MAX(0, [self.posts count] - self.newestPostIndex);
}

@end
