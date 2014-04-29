//  AwfulPostViewModel.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostViewModel.h"
#import "AwfulDateFormatters.h"
#import "AwfulHTMLRendering.h"
#import "AwfulSettings.h"

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
    RemoveSpoilerStylingAndEvents(document);
    RemoveEmptyEditedByParagraphs(document);
    UseHTML5VimeoPlayer(document);
    HighlightQuotesOfPostsByUserNamed(document, [AwfulSettings settings].username);
    if (![AwfulSettings settings].showImages) {
        LinkifyNonSmileyImages(document);
    }
    if (self.post.ignored) {
        MarkRevealIgnoredPostLink(document);
    }
    return [document firstNodeMatchingSelector:@"body"].innerHTML;
}

static void MarkRevealIgnoredPostLink(HTMLDocument *document)
{
    HTMLElement *link = [document firstNodeMatchingSelector:@"a[title=\"DON'T DO IT!!\"]"];
    if (!link) return;
    NSURLComponents *components = [NSURLComponents componentsWithString:link[@"href"]];
    components.fragment = @"awful-ignored";
    link[@"href"] = components.URL.absoluteString;
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
