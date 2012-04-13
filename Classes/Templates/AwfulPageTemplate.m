//
//  AwfulPageTemplate.m
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageTemplate.h"
#import "AwfulPost.h"
#import "TFHpple.h"
#import "TFHppleElement.h"
#import "AwfulConfig.h"
#import "AwfulPageDataController.h"
#import "AwfulPageCount.h"
#import "SALR.h"
#import "GRMustacheTemplate.h"

@interface PostContext : NSObject

// Designated initializer.
- (id)initWithPost:(AwfulPost *)post;

@property (strong) NSString *postID;
@property (assign) BOOL isOP;
@property (strong) NSString *avatarURL;
@property (assign) BOOL isMod;
@property (assign) BOOL isAdmin;
@property (strong) NSString *posterName;
@property (strong) NSString *postDate;

// either 'altcolor1', 'altcolor2', 'seen1', or 'seen2' depending on the post index (even/odd)
@property (strong) NSString *altCSSClass;

@property (strong) NSString *postBody;

@end

@implementation PostContext

static NSString *AwfulifiedPostBody(NSString *body);

- (id)initWithPost:(AwfulPost *)post
{
    self = [super init];
    if (self)
    {
        _postID = post.postID;
        _isOP = post.isOP;
        _avatarURL = [AwfulConfig showAvatars] ? [post.avatarURL absoluteString] : nil;
        _isMod = post.posterType == AwfulUserTypeMod;
        _isAdmin = post.posterType == AwfulUserTypeAdmin;
        _posterName = post.posterName;
        _postDate = post.postDate;
        _altCSSClass = post.altCSSClass;
        _postBody = AwfulifiedPostBody(post.postBody);
    }
    return self;
}

static NSString *AwfulifiedPostBody(NSString *body)
{
    TFHpple *base = [[TFHpple alloc] initWithHTMLData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    NSMutableString *awfulified = [body mutableCopy];
    
    // Replace images with links if so desired.
    if (![AwfulConfig showImages]) {
        NSArray *objects = [base search:@"//img"];
        NSArray *object_strs = [base rawSearch:@"//img"];
        for(int i = 0; i < [objects count]; i++) {
            TFHppleElement *el = [objects objectAtIndex:i];
            NSString *src = [el objectForKey:@"src"];
            NSString *reformed = [NSString stringWithFormat:@"<a href='%@'>IMG LINK</a>", src];
            [awfulified replaceOccurrencesOfString:[object_strs objectAtIndex:i]
                                        withString:reformed
                                           options:0
                                             range:NSMakeRange(0, awfulified.length)];
        }
    }
    
    // Replace embedded youtube/vimeo with links.
    NSArray *objects = [base search:@"//object/param[@name='movie']"];
    NSArray *object_strs = [base rawSearch:@"//object"];
    
    for (int i = 0; i < [objects count]; i++) {
        TFHppleElement *el = [objects objectAtIndex:i];
        NSRange r = [[el objectForKey:@"value"] rangeOfString:@"youtube"];
        if (r.location != NSNotFound) {
            NSURL *youtube_url = [NSURL URLWithString:[el objectForKey:@"value"]];
            NSString *youtube_str = [NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", [youtube_url lastPathComponent]];
            NSString *reformed_youtube = [NSString stringWithFormat:@"<a href='%@'>Embedded YouTube</a>", youtube_str];
            if (i < [object_strs count]) {
                [awfulified replaceOccurrencesOfString:[object_strs objectAtIndex:i]
                                            withString:reformed_youtube
                                               options:0
                                                 range:NSMakeRange(0, awfulified.length)];
            }
        } else {
            r = [[el objectForKey:@"value"] rangeOfString:@"vimeo"];
            if (r.location != NSNotFound) {
                NSRange clip = [[el objectForKey:@"value"] rangeOfString:@"clip_id="];
                NSRange and = [[el objectForKey:@"value"] rangeOfString:@"&"];
                NSRange clip_range;
                clip_range.location = clip.location + 8;
                clip_range.length = and.location - clip.location - 8;
                NSString *clip_id = [[el objectForKey:@"value"] substringWithRange:clip_range];
                NSString *reformed_vimeo = [NSString stringWithFormat:@"<a href='http://www.vimeo.com/m/#/%@'>Embedded Vimeo</a>", clip_id];
                [awfulified replaceOccurrencesOfString:[object_strs objectAtIndex:i]
                                            withString:reformed_vimeo
                                               options:0
                                                 range:NSMakeRange(0, awfulified.length)];
            }
        }
    }
    
    // TODO what's going on here?
    [awfulified replaceOccurrencesOfString:@"&#13;"
                                withString:@""
                                   options:0
                                     range:NSMakeRange(0, awfulified.length)];
    
    return awfulified;
}

@synthesize postID = _postID;
@synthesize isOP = _isOP;
@synthesize avatarURL = _avatarURL;
@synthesize isMod = _isMod;
@synthesize isAdmin = _isAdmin;
@synthesize posterName = _posterName;
@synthesize postDate = _postDate;
@synthesize altCSSClass = _altCSSClass;
@synthesize postBody = _postBody;

@end

@interface AwfulPageTemplate ()

@property (readonly, nonatomic) NSArray *javascripts;
@property (readonly, nonatomic) NSString *salrConfig;
@property (strong) NSArray *posts;
@property (strong) NSString *pagesLeftNotice;
@property (strong) NSString *userAd;
@property (assign) BOOL showAvatars;

@end

@implementation AwfulPageTemplate

-(NSString *)constructHTMLFromPageDataController : (AwfulPageDataController *)dataController
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
    for(AwfulPost *post in dataController.posts) {
        [posts addObject:[[PostContext alloc] initWithPost:post]];
    }
    self.posts = posts;
    
    NSString *resource = @"phone-template";
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        resource = @"pad-template";
    NSError *mustacheError;
    return [GRMustacheTemplate renderObject:self
                               fromResource:resource
                              withExtension:@"html"
                                     bundle:nil
                                      error:&mustacheError];
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

@synthesize userAd = _userAd;

@synthesize showAvatars = _showAvatars;

@end

@implementation NSString (AwfulAdditions)

-(NSString *)stringByTrimmingBetweenBeginString : (NSString *)beginString endString : (NSString *)endString
{
    NSRange begin_range = [self rangeOfString:beginString];
    NSRange end_range = [self rangeOfString:endString];
    NSRange content_range = NSMakeRange(begin_range.location, (end_range.location - begin_range.location) + end_range.length);
    return [self stringByReplacingCharactersInRange:content_range withString:@""];
}

-(NSString *)stringByRemovingStrings : (NSString *)first, ...
{
    NSString *content = self;
    va_list args;
    va_start(args, first);
    for(NSString *str = first; str != nil; str = va_arg(args, NSString *)) {
        content = [content stringByReplacingOccurrencesOfString:str withString:@""];
    }
    va_end(args);
    return content;
}

-(NSString *)substringBetweenBeginString : (NSString *)beginString endString : (NSString *)endString
{
    NSRange begin_range = [self rangeOfString:beginString];
    NSRange end_range = [self rangeOfString:endString];
    if(begin_range.location != NSNotFound && end_range.location != NSNotFound) {
        NSRange content_range = NSMakeRange(begin_range.location+begin_range.length, end_range.location - (begin_range.location+begin_range.length));
        if(content_range.location + content_range.length <= [self length]) {
            return [self substringWithRange:content_range];
        }
    }
    return @"";
}

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

/*
Notes:
  - One element needs an id of {%POST_ID%} so the app knows where to scroll down to for the 'newest post'.
  - tappedPost('{%POST_ID%}') is some javascript that will show the post actions in the app. E.g. 'Quote', 'Mark up to here', etc...
  - the tappedBottom() javascript triggers a 'next page' call if there are pages left
*/
