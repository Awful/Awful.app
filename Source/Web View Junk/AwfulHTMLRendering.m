//  AwfulHTMLRendering.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulHTMLRendering.h"

void HighlightQuotesOfPostsByUserNamed(HTMLDocument *document, NSString *username)
{
    NSString *loggedInUserPosted = [username stringByAppendingString:@" posted:"];
    for (HTMLElement *h4 in [document nodesMatchingSelector:@".bbc-block h4"]) {
        if ([h4.textContent isEqualToString:loggedInUserPosted]) {
            HTMLElement *block = h4.parentElement;
            while (block && ![block hasClass:@"bbc-block"]) {
                block = block.parentElement;
            }
            [block toggleClass:@"mention"];
        }
    }
}

static BOOL IsSmilieURL(NSURL*);

void LinkifyNonSmilieImages(HTMLDocument *document)
{
    for (HTMLElement *img in [document nodesMatchingSelector:@"img"]) {
        NSURL *src = [NSURL URLWithString:img[@"src"]];
        if (!IsSmilieURL(src)) {
            HTMLElement *link = [[HTMLElement alloc] initWithTagName:@"span" attributes:@{ @"data-awful-linkified-image": @"" }];
            link.textContent = src.absoluteString;
            NSMutableOrderedSet *imgSiblings = [img.parentNode mutableChildren];
            [imgSiblings replaceObjectAtIndex:[imgSiblings indexOfObject:img] withObject:link];
        }
    }
}

void RemoveEmptyEditedByParagraphs(HTMLDocument *document)
{
    for (HTMLElement *element in [document nodesMatchingSelector:@"p.editedby"]) {
        NSString *textContent = [element.textContent stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (textContent.length == 0) {
            [[element.parentNode mutableChildren] removeObject:element];
        }
    }
}

void RemoveSpoilerStylingAndEvents(HTMLDocument *document)
{
    for (HTMLElement *element in [document nodesMatchingSelector:@"span.bbc-spoiler"]) {
        [element removeAttributeWithName:@"onmouseover"];
        [element removeAttributeWithName:@"onmouseout"];
        [element removeAttributeWithName:@"style"];
    }
}

void UseHTML5VimeoPlayer(HTMLDocument *document)
{
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
}

static BOOL IsSmilieURL(NSURL *URL)
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
    
    // http://media.votefinder.org (games of Mafia)
    else if ([host caseInsensitiveCompare:@"media.votefinder.org"] == NSOrderedSame) {
        return YES;
    }
    
    return NO;
}
