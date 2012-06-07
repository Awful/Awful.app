//
//  AwfulPageTemplate.m
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageTemplate.h"
#import "AwfulPageDataController.h"
#import "AwfulPageCount.h"
#import "AwfulPost.h"
#import "AwfulSettings.h"
#import "GRMustacheTemplate.h"
#import "PostContext.h"
#import "SALR.h"
#import "AwfulForum.h"

/*
 Notes:
 - One element needs an id of {%POST_ID%} so the app knows where to scroll down to for the 'newest post'.
 - tappedPost('{%POST_ID%}') is some javascript that will show the post actions in the app. E.g. 'Quote', 'Mark up to here', etc...
 - the tappedBottom() javascript triggers a 'next page' call if there are pages left
 */


@interface TemplateContext : NSObject

// Designated initializer.
- (id)initWithPageDataController:(AwfulPageDataController *)dataController overridePostRemover : (BOOL)overridePostRemover;

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

@synthesize template = _template;

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

-(NSURL *)getTemplateURLFromForum : (AwfulForum *)forum
{
    if([[AwfulSettings settings] darkTheme]) {
        NSString *darkName = @"dark.css";
        NSURL *defaultDarkURL = [[ApplicationDelegate applicationDocumentsDirectory] URLByAppendingPathComponent:darkName];
        if([defaultDarkURL checkResourceIsReachableAndReturnError:nil]) {
            return defaultDarkURL;
        }
        return [[NSBundle mainBundle] URLForResource:darkName withExtension:nil];
    }
    
    if(forum != nil) {
        NSString *name = [NSString stringWithFormat:@"%@.css", forum.forumID];
        NSURL *url = [[ApplicationDelegate applicationDocumentsDirectory] URLByAppendingPathComponent:name];
        if([url checkResourceIsReachableAndReturnError:nil]) {
            return url;
        }
    }
    
    NSString *defaultName = @"default.css";    
    NSURL *defaultURL = [[ApplicationDelegate applicationDocumentsDirectory] URLByAppendingPathComponent:defaultName];
    if([defaultURL checkResourceIsReachableAndReturnError:nil]) {
        return defaultURL;
    }
    
    return [[NSBundle mainBundle] URLForResource:defaultName withExtension:nil];
}

- (NSString *)renderWithPageDataController:(AwfulPageDataController *)dataController displayAllPosts : (BOOL)displayAllPosts
{
    TemplateContext *context = [[TemplateContext alloc] initWithPageDataController:dataController overridePostRemover:displayAllPosts];
    context.cssURL = [self getTemplateURLFromForum:dataController.forum];
    return [self.template renderObject:context];
}

- (NSString *)renderWithPageDataController:(AwfulPageDataController *)dataController
{
    return [self renderWithPageDataController:dataController displayAllPosts:NO];
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

- (id)initWithPageDataController:(AwfulPageDataController *)dataController overridePostRemover : (BOOL)overridePostRemover
{
    self = [super init];
    if (self)
    {
        self.userAd = dataController.userAd;
        NSUInteger pages_left = [dataController.pageCount getPagesLeft];
        if(pages_left > 1) {
            self.pagesLeftNotice = [NSString stringWithFormat:@"%d pages left.", pages_left];
        } else if(pages_left == 1) {
            self.pagesLeftNotice = @"1 page left.";
        } else {
            self.pagesLeftNotice = @"End of the thread.";
        }
        NSMutableArray *posts = [NSMutableArray array];
        int currentIndex = 0;
        int numPostsAbove = [[AwfulSettings settings] loadReadPosts];
        int firstPostIndex = MAX(dataController.newestPostIndex - numPostsAbove, 0);
        int numHiddenPosts = 0;
        
        // no new posts on a page, show them all!
        if([dataController.posts count] == dataController.newestPostIndex) { 
            firstPostIndex = 0;
        }
        
        for(AwfulPost *post in dataController.posts) {
            if(currentIndex >= firstPostIndex || overridePostRemover) {
                [posts addObject:[[PostContext alloc] initWithPost:post]];
            } else {
                numHiddenPosts++;
            }
            currentIndex++;
        }
        if(numHiddenPosts > 0) {
            if(numHiddenPosts == 1) {
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
