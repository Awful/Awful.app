//  AwfulPostViewModel.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostViewModel.h"
#import "AwfulDateFormatters.h"
#import "AwfulSettings.h"
#import <HTMLReader/HTMLReader.h>

@implementation AwfulPostViewModel

- (id)initWithPost:(AwfulPost *)post
{
    self = [super init];
    if (!self) return nil;
    
    _post = post;
    
    return self;
}

- (NSString *)HTMLContents
{
    HTMLDocument *document = [HTMLDocument documentWithString:self.post.innerHTML];
    
    // We'll style spoilers ourselves.
    for (HTMLElement *element in [document nodesMatchingSelector:@"span.bbc-spoiler"]) {
        [element removeAttributeWithName:@"onmouseover"];
        [element removeAttributeWithName:@"onmouseout"];
        [element removeAttributeWithName:@"style"];
    }
    
    // Empty "editedby" paragraphs make for ugly spacing.
    for (HTMLElement *element in [document nodesMatchingSelector:@".editedby"]) {
        if (element.textContent.length == 0) {
            [[element.parentNode mutableChildren] removeObject:element];
        }
    }
    
    // Vimeo embeds get stuck on the Flash player. Swap it out for the HTML5 player.
    for (HTMLElement *param in [document nodesMatchingSelector:@"div.bbcode_video object param[name='movie'][value^='http://vimeo.com/']"]) {
        NSURL *sourceURL = [NSURL URLWithString:param[@"value"]];
        NSString *clipID = sourceURL.queryDictionary[@"clip_id"];
        if (clipID.length == 0) continue;
        HTMLElement *object = param.parentElement;
        if (![object.tagName isEqualToString:@"object"]) continue;
        HTMLElement *div = object.parentElement;
        if (![div.tagName isEqualToString:@"div"] || ![div hasClass:@"bbcode_video"]) continue;
        
        NSURLComponents *iframeSource = [NSURLComponents componentsWithString:@"http://player.vimeo.com/video/"];
        iframeSource.path = [iframeSource.path stringByAppendingPathComponent:clipID];
        iframeSource.query = @"byline=0&portrait=0";
        HTMLElement *iframe = [[HTMLElement alloc] initWithTagName:@"iframe" attributes:@{ @"src": iframeSource.URL.absoluteString,
                                                                                           @"width": object[@"width"] ?: @"400",
                                                                                           @"height": object[@"height"] ?: @"225",
                                                                                           @"frameborder": @"0",
                                                                                           @"webkitAllowFullScreen": @"",
                                                                                           @"allowFullScreen": @"" }];
        NSMutableOrderedSet *divSiblings = [div.parentNode mutableChildren];
        [divSiblings replaceObjectAtIndex:[divSiblings indexOfObject:div] withObject:iframe];
    }
    
    // Hide non-smiley images when requested.
    if (![AwfulSettings settings].showImages) {
        for (HTMLElement *img in [document nodesMatchingSelector:@"img"]) {
            NSURL *src = [NSURL URLWithString:img[@"src"]];
            if (!IsSmileyURL(src)) {
                HTMLElement *link = [[HTMLElement alloc] initWithTagName:@"a" attributes:@{ @"data-awful": @"image" }];
                link.textContent = src.absoluteString;
                NSMutableOrderedSet *imgSiblings = [img.parentNode mutableChildren];
                [imgSiblings replaceObjectAtIndex:[imgSiblings indexOfObject:img] withObject:link];
            }
        }
    }
    
    // Highlight the logged-in user's quotes.
    NSString *loggedInUserPosted = [NSString stringWithFormat:@"%@ posted:", [AwfulSettings settings].username];
    for (HTMLElement *h4 in [document nodesMatchingSelector:@".bbc-block h4"]) {
        if ([h4.textContent isEqualToString:loggedInUserPosted]) {
            [h4 toggleClass:@"mention"];
        }
    }
    
    return [document firstNodeMatchingSelector:@"body"].innerHTML;
}

static BOOL IsSmileyURL(NSURL *URL)
{
    NSString *host = URL.host;
    if (host.length == 0) return NO;
    
    // http://fi.somethingawful.com/images/smilies
    // http://fi.somethingawful.com/safs/smilies
    // http://fi.somethingawful.com/forums/posticons
    if ([host caseInsensitiveCompare:@"fi.somethingawful.com"] == NSOrderedSame) {
        NSArray *pathComponents = URL.pathComponents;
        if ([pathComponents containsObject:@"smilies"] || [pathComponents containsObject:@"posticons"]) {
            return YES;
        }
    }
    
    // http://i.somethingawful.com/images/emot
    // http://i.somethingawful.com/forumsystem/emoticons
    else if ([host caseInsensitiveCompare:@"i.somethingawful.com"] == NSOrderedSame) {
        NSArray *pathComponents = URL.pathComponents;
        if ([pathComponents containsObject:@"emot"] || [pathComponents containsObject:@"emoticons"]) {
            return YES;
        }
    }
    
    // http://forumimages.somethingawful.com/forums/posticons
    // http://forumimages.somethingawful.com/images
    else if ([host caseInsensitiveCompare:@"forumimages.somethingawful.com"] == NSOrderedSame) {
        NSArray *pathComponents = URL.pathComponents;
        if ([pathComponents.firstObject isEqualToString:@"images"] || [pathComponents containsObject:@"posticons"]) {
            return YES;
        }
    }
    return NO;
}

- (NSURL *)visibleAvatarURL
{
    return [self showAvatars] ? self.post.author.avatarURL : nil;
}

- (NSURL *)hiddenAvatarURL
{
    return [self showAvatars] ? nil : self.post.author.avatarURL;
}

- (BOOL)showAvatars
{
    return [AwfulSettings settings].showAvatars;
}

- (NSArray *)roles
{
    NSMutableArray *roles = [NSMutableArray new];
    AwfulPost *post = self.post;
    AwfulUser *author = post.author;
    if ([author isEqual:post.thread.author]) {
        [roles addObject:@"op"];
    }
    if (author.moderator) {
        [roles addObject:@"mod"];
    }
    if (author.administrator) {
        [roles addObject:@"admin"];
    }
    if (author.idiotKing) {
        [roles addObject:@"ik"];
    }
    return roles;
}

- (BOOL)authorIsOP
{
    return [self.post.author isEqual:self.post.thread.author];
}

- (NSDateFormatter *)postDateFormat
{
    return [AwfulDateFormatters postDateFormatter];
}

- (NSDateFormatter *)regDateFormat
{
    return [AwfulDateFormatters regDateFormatter];
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.post valueForKey:key];
}

@end
