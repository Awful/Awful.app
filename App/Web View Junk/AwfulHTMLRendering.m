//  AwfulHTMLRendering.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulHTMLRendering.h"
@import AwfulCore;

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

static BOOL IsSmileyURL(NSURL*);

void ProcessImgTags(HTMLDocument *document, BOOL linkifyNonSmiles)
{
    for (HTMLElement *img in [document nodesMatchingSelector:@"img"]) {
        NSURL *src = [NSURL URLWithString:img[@"src"]];
        if (!IsSmileyURL(src)) {
            if (linkifyNonSmiles) {
                HTMLElement *link = [[HTMLElement alloc] initWithTagName:@"span" attributes:@{ @"data-awful-linkified-image": @"" }];
                link.textContent = src.absoluteString;
                NSMutableOrderedSet *imgSiblings = [img.parentNode mutableChildren];
                [imgSiblings replaceObjectAtIndex:[imgSiblings indexOfObject:img] withObject:link];
            }
        } else {
            [img toggleClass:@"awful-smile"];
        }
    }
}

void StopGifAutoplay(HTMLDocument *document)
{
	for (HTMLElement *img in [document nodesMatchingSelector:@"img"]) {
		NSURL *src = [NSURL URLWithString:img[@"src"]];
		if([src.pathExtension  isEqual: @"gif"]) {
			NSString *newUrl = @"";
            if([src.host rangeOfString:@"imgur.com"].location != NSNotFound) {
				newUrl = [src.absoluteString stringByReplacingOccurrencesOfString:@".gif" withString: @"h.jpg"];
			}
			else if ([src.host caseInsensitiveCompare:@"i.kinja-img.com"] == NSOrderedSame) {
				newUrl = [src.absoluteString stringByReplacingOccurrencesOfString:@".gif" withString: @".jpg"];
			}
			else if ([src.host caseInsensitiveCompare:@"i.giphy.com"] == NSOrderedSame) {
				newUrl = [src.absoluteString stringByReplacingOccurrencesOfString:@"://i.giphy.com" withString: @"s://media.giphy.com/media"];
				newUrl = [newUrl stringByReplacingOccurrencesOfString:@".gif" withString: @"/200_s.gif"];
			}
			else if ([src.host caseInsensitiveCompare:@"giant.gfycat.com"] == NSOrderedSame) {
				newUrl = [src.absoluteString stringByReplacingOccurrencesOfString:@"giant.gfycat.com" withString: @"thumbs.gfycat.com"];
				newUrl = [newUrl stringByReplacingOccurrencesOfString:@".gif" withString: @"-poster.jpg"];
			}
            if(![newUrl isEqual: @""]) {
                HTMLElement *imgParent = img.parentElement;
 				HTMLElement *replacedImg = [[HTMLElement alloc] initWithTagName:@"img" attributes:@{ @"src": newUrl, @"class": @"imgurGif", @"data-originalurl": src.absoluteString, @"data-posterurl": newUrl }];
				
				NSMutableOrderedSet *children = [replacedImg.parentNode mutableChildren];
				HTMLElement *wrapper = [[HTMLElement alloc] initWithTagName:@"div" attributes:@{@"class": @"gifWrap"}];
				[children insertObject:wrapper atIndex:[children indexOfObject:replacedImg]];
                replacedImg.parentNode = wrapper;
                
                NSMutableOrderedSet *imgSiblings = [img.parentNode mutableChildren];
                if ([imgParent.tagName isEqualToString:@"a"]) {
                    NSURL *linkUrl = [NSURL URLWithString:imgParent[@"href"]];
                    HTMLElement *externalLink = [[HTMLElement alloc] initWithTagName:@"a" attributes:@{@"href": linkUrl}];
                    externalLink.textContent = linkUrl.absoluteString;
                    [imgSiblings insertObject:externalLink atIndex:[imgSiblings indexOfObject:img]];
                    
                }
                [imgSiblings replaceObjectAtIndex:[imgSiblings indexOfObject:img] withObject:wrapper];
			}
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
    for (HTMLElement *param in [document nodesMatchingSelector:@"div.bbcode_video object param[name='movie'][value*='://vimeo.com/']"]) {
        NSURL *sourceURL = [NSURL URLWithString:param[@"value"]];
        NSString *clipID = sourceURL.awful_queryDictionary[@"clip_id"];
        if (clipID.length == 0) continue;
        HTMLElement *object = param.parentElement;
        if (![object.tagName isEqualToString:@"object"]) continue;
        HTMLElement *div = object.parentElement;
        if (![div.tagName isEqualToString:@"div"] || ![div hasClass:@"bbcode_video"]) continue;
        
        NSURLComponents *iframeSource = [NSURLComponents componentsWithString:@"https://player.vimeo.com/video/"];
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

static BOOL IsSmileyURL(NSURL *URL)
{
    NSString *host = URL.host;
    if (host.length == 0) return NO;
    
    // http://fi.somethingawful.com/images/smilies
    // http://fi.somethingawful.com/safs/smilies
    // http://fi.somethingawful.com/forums/posticons
    // http://fi.somethingawful.com/customtitles{/eris}
    if ([host caseInsensitiveCompare:@"fi.somethingawful.com"] == NSOrderedSame) {
        NSArray *pathComponents = URL.pathComponents;
        if ([pathComponents containsObject:@"smilies"] || [pathComponents containsObject:@"posticons"] ||
            [pathComponents containsObject:@"customtitles"]) {
            return YES;
        }
    }
    
    // http://i.somethingawful.com/images/*.gif
    // http://i.somethingawful.com/images/emot
    // http://i.somethingawful.com/forumsystem/emoticons
    // http://i.somethingawful.com/mjolnir/images
    // http://i.somethingawful.com/u/adminuploads/
    // http://i.somethingawful.com/u/garbageday/
    else if ([host caseInsensitiveCompare:@"i.somethingawful.com"] == NSOrderedSame) {
        NSArray *pathComponents = URL.pathComponents;
        if ([pathComponents containsObject:@"emot"] || [pathComponents containsObject:@"emoticons"]) {
            return YES;
        }
        if ([pathComponents containsObject:@"images"]) {
            return YES;
        }
        if ([pathComponents containsObject:@"mjolnir"] && [pathComponents containsObject:@"images"]) {
            return YES;
        }
        if ([pathComponents containsObject:@"u"] && ([pathComponents containsObject:@"adminuploads"] || [pathComponents containsObject:@"garbageday"])) {
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
