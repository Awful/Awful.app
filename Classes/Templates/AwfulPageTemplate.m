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
#import "AwfulConfig.h"
#import "PostContext.h"
#import "SALR.h"
#import "GRMustacheTemplate.h"

/*
 Notes:
 - One element needs an id of {%POST_ID%} so the app knows where to scroll down to for the 'newest post'.
 - tappedPost('{%POST_ID%}') is some javascript that will show the post actions in the app. E.g. 'Quote', 'Mark up to here', etc...
 - the tappedBottom() javascript triggers a 'next page' call if there are pages left
 */


@interface TemplateContext : NSObject

// Designated initializer.
- (id)initWithPageDataController:(AwfulPageDataController *)dataController;

@property (readonly, nonatomic) NSArray *javascripts;
@property (readonly, nonatomic) NSString *salrConfig;
@property (strong) NSArray *posts;
@property (strong) NSString *pagesLeftNotice;
@property (strong) NSString *postsAboveNotice;
@property (strong) NSString *userAd;
@property (assign) BOOL showAvatars;

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
        NSString *resource = @"phone-template";
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
            resource = @"pad-template";
        NSError *error;
        _template = [GRMustacheTemplate templateFromResource:resource
                                               withExtension:@"html"
                                                      bundle:nil
                                                       error:&error];
        if (!_template)
            NSLog(@"error parsing template %@: %@", resource, error);
    }
    return _template;
}

- (NSString *)renderWithPageDataController:(AwfulPageDataController *)dataController
{
    TemplateContext *context = [[TemplateContext alloc] initWithPageDataController:dataController];
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

- (id)initWithPageDataController:(AwfulPageDataController *)dataController
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
        NSUInteger currentIndex = 0;
        for(AwfulPost *post in dataController.posts) {
            if(currentIndex >= dataController.newestPostIndex || YES) {
                [posts addObject:[[PostContext alloc] initWithPost:post]];
            }
            currentIndex++;
        }
        self.posts = posts;
        self.postsAboveNotice = @"No Posts Above";
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

@end
