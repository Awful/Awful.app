//
//  AwfulPageTemplate.m
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageTemplate.h"
#import "AwfulModels.h"
#import "AwfulParsing.h"
#import "AwfulSettings.h"
#import "GRMustacheTemplate.h"
#import "PostContext.h"
#import "SALR.h"

/*
 Notes:
 - One element needs an id of {%POST_ID%} so the app knows where to scroll down to for the 'newest post'.
 - tappedPost('{%POST_ID%}') is some javascript that will show the post actions in the app. E.g. 'Quote', 'Mark up to here', etc...
 - the tappedBottom() javascript triggers a 'next page' call if there are pages left
 */

static NSURL *DefaultCSSURL()
{
    return [[NSBundle mainBundle] URLForResource:@"default.css" withExtension:nil];
}


@interface TemplateContext : NSObject

// Designated initializer.
- (id)initWithPageInfo:(PageParsedInfo *)pageInfo overridePostRemover:(BOOL)overridePostRemover;

@property (readonly, nonatomic) NSArray *javascripts;
@property (readonly, nonatomic) NSString *salrConfig;
@property (strong) NSURL *cssURL;
@property (readonly, nonatomic) NSString *css;
@property (readonly, nonatomic) NSString *device;
@property (strong) NSArray *posts;
@property (strong) NSString *pagesLeftNotice;
@property (strong) NSString *postsAboveNotice;
@property (strong) NSString *userAd;
@property (assign) BOOL showAvatars;

@end


@interface AwfulPageTemplate ()

@property (strong, nonatomic) GRMustacheTemplate *template;

@end

@implementation AwfulPageTemplate

- (GRMustacheTemplate *)template
{
    if (_template) {
        return _template;
    }
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"posts" withExtension:@"html"];
    NSError *error;
    _template = [GRMustacheTemplate templateFromContentsOfURL:url error:&error];
    if (!_template) {
        NSLog(@"error compiling posts template: %@", error);
    }
    return _template;
}

// Template files are searched for in the following order in the documents directory
// (where ## is the forum ID):
//
//   1. dark-##.css (if dark theme is enabled)
//   2. default-##.css
//   3. dark.css (if dark theme is enabled)
//   4. default.css
//
// If no template is found, steps 1-4 are repeated in the application's resources directory.
- (NSURL *)getTemplateURLFromForumWithID:(NSString *)forumID
{
    NSArray *listOfFilenames = @[
        [NSString stringWithFormat:@"default-%@.css", forumID],
        @"default.css"
    ];
    if (AwfulSettings.settings.darkTheme) {
        listOfFilenames = @[
            [NSString stringWithFormat:@"dark-%@.css", forumID],
            listOfFilenames[0],
            @"dark.css",
            listOfFilenames[1]
        ];
    }
    for (NSString *filename in listOfFilenames) {
        NSURL *documents = [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory
                                                                   inDomains:NSUserDomainMask] lastObject];
        NSURL *url = [documents URLByAppendingPathComponent:filename];
        if ([url checkResourceIsReachableAndReturnError:NULL]) return url;
    }
    for (NSString *filename in listOfFilenames) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:filename withExtension:nil];
        if ([url checkResourceIsReachableAndReturnError:NULL]) return url;
    }
    return nil;
}

- (NSString *)renderWithPageInfo:(PageParsedInfo *)pageInfo displayAllPosts:(BOOL)displayAllPosts
{
    TemplateContext *context = [[TemplateContext alloc] initWithPageInfo:pageInfo
                                                     overridePostRemover:displayAllPosts];
    context.cssURL = [self getTemplateURLFromForumWithID:pageInfo.forumID];
    return [self.template renderObject:context];
}

@end


@interface NSString (AwfulAdditions)

+ (NSString *)awful_stringResource:(NSString *)name withExtension:(NSString *)extension;

@end

@implementation NSString (AwfulAdditions)

+ (NSString *)awful_stringResource:(NSString *)name withExtension:(NSString *)extension
{
    NSURL *url = [[NSBundle mainBundle] URLForResource:name withExtension:extension];
    if (!url)
        return nil;
    NSError *error;
    NSString *string = [[NSString alloc] initWithContentsOfURL:url
                                                      encoding:NSUTF8StringEncoding
                                                         error:&error];
    if (!string)
        NSLog(@"error fetching string from file %@.%@: %@", name, extension, error);
    return string;
}

@end


@implementation TemplateContext

- (id)initWithPageInfo:(PageParsedInfo *)pageInfo overridePostRemover:(BOOL)overridePostRemover
{
    self = [super init];
    if (self)
    {
        self.userAd = pageInfo.advertisementHTML;
        NSInteger pagesLeft = pageInfo.pagesInThread - pageInfo.pageNumber;
        if (pagesLeft > 1) {
            self.pagesLeftNotice = [NSString stringWithFormat:@"%d pages left.", pagesLeft];
        } else if (pagesLeft == 1) {
            self.pagesLeftNotice = @"1 page left.";
        } else {
            self.pagesLeftNotice = @"End of the thread. Tap to refresh.";
        }
        NSMutableArray *posts = [NSMutableArray array];
        int currentIndex = 0;
        int numPostsAbove = [[AwfulSettings settings] loadReadPosts];
        int firstPostIndex = [pageInfo.posts count];
        for (NSUInteger i = 0; i < [pageInfo.posts count]; i++) {
            PostParsedInfo *post = pageInfo.posts[i];
            if (!post.beenSeen) {
                firstPostIndex = i;
                break;
            }
        }
        int numHiddenPosts = 0;
        
        // no new posts on a page, show them all!
        if ([pageInfo.posts count] == (NSUInteger)firstPostIndex) {
            firstPostIndex = 0;
        } else {
            firstPostIndex -= numPostsAbove;
            if (firstPostIndex < 0) firstPostIndex = 0;
        }
        
        for (PostParsedInfo *post in pageInfo.posts) {
            if (currentIndex >= firstPostIndex || overridePostRemover) {
                [posts addObject:[[PostContext alloc] initWithPostInfo:post]];
            } else {
                numHiddenPosts++;
            }
            currentIndex++;
        }
        if (numHiddenPosts > 0) {
            if (numHiddenPosts == 1) {
                self.postsAboveNotice = @"1 Post Above";
            } else {
                self.postsAboveNotice = [NSString stringWithFormat:@"%d Posts Above", numHiddenPosts];
            }
        }
        self.posts = posts;
    }
    return self;
}

@synthesize javascripts = _javascripts;

- (NSArray *)javascripts
{
    if (!_javascripts)
    {
        _javascripts = [NSArray arrayWithObjects:
                        [NSString awful_stringResource:@"jquery" withExtension:@"js"],
                        [NSString awful_stringResource:@"salr" withExtension:@"js"],
                        [NSString awful_stringResource:@"ObjCBridge" withExtension:@"js"],
                        [NSString awful_stringResource:@"awful" withExtension:@"js"],
                        nil];
    }
    return _javascripts;
}

@synthesize cssURL = _cssURL;
@synthesize css = _css;

- (NSString *)css
{
    if (!_css) {
        NSError *error;
        _css = [NSString stringWithContentsOfURL:self.cssURL
                                        encoding:NSUTF8StringEncoding
                                           error:&error];
        if (!_css) {
            NSLog(@"error loading css from %@: %@", self.cssURL, error);
        }
        if (![self.cssURL isEqual:DefaultCSSURL()]) {
            NSString *cssBed = [NSString stringWithContentsOfURL:DefaultCSSURL()
                                                        encoding:NSUTF8StringEncoding
                                                           error:&error];
            if (!cssBed) {
                NSLog(@"error loading default css from %@: %@", DefaultCSSURL(), error);
            }
            _css = [cssBed stringByAppendingString:_css];
        }
    }
    return _css;
}

- (NSString *)salrConfig
{
    return [SALR config];
}

- (NSString *)device
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return @"ipad";
    }
    return @"iphone";
}

@synthesize posts = _posts;

@synthesize pagesLeftNotice = _pagesLeftNotice;

@synthesize postsAboveNotice = _postsAboveNotice;

@synthesize userAd = _userAd;

@synthesize showAvatars = _showAvatars;

@end
