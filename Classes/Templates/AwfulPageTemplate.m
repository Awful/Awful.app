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
@property (strong) NSArray *posts;
@property (strong) NSString *pagesLeftNotice;
@property (strong) NSString *postsAboveNotice;
@property (strong) NSString *userAd;
@property (assign) BOOL showAvatars;

- (BOOL)isPhoneDevice;
- (BOOL)isPadDevice;

@end


@interface AwfulPageTemplate ()

@property (readonly, nonatomic) GRMustacheTemplate *template;

@end

@implementation AwfulPageTemplate

@synthesize template = _template;

- (GRMustacheTemplate *)template
{
    if (!_template)
    {
        // check docs folder first, if not in there use templates supplied by default
        
        NSURL *templateURL = [[ApplicationDelegate applicationDocumentsDirectory] URLByAppendingPathComponent:@"template.html"];
        
        NSError *err = nil;
        if([templateURL checkResourceIsReachableAndReturnError:nil]) {
            _template = [GRMustacheTemplate templateFromContentsOfURL:templateURL error:&err];
        } else {
            _template = [GRMustacheTemplate templateFromResource:@"template"
                                                   withExtension:@"html"
                                                          bundle:nil
                                                           error:&err];
        }
        
        if (!_template) {
            NSLog(@"error parsing template %@", [err localizedDescription]);
        }
    }
    return _template;
}

- (NSString *)renderWithPageDataController:(AwfulPageDataController *)dataController displayAllPosts : (BOOL)displayAllPosts
{
    TemplateContext *context = [[TemplateContext alloc] initWithPageDataController:dataController overridePostRemover:displayAllPosts];
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
                        nil];
    }
    return _javascripts;
}

- (NSString *)salrConfig
{
    return [SALR config];
}

@synthesize posts = _posts;

@synthesize pagesLeftNotice = _pagesLeftNotice;

@synthesize postsAboveNotice = _postsAboveNotice;

@synthesize userAd = _userAd;

@synthesize showAvatars = _showAvatars;

- (BOOL)isPhoneDevice
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone;
}

- (BOOL)isPadDevice
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
}

@end
