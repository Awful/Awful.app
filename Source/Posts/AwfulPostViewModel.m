//  AwfulPostViewModel.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostViewModel.h"
#import "AwfulHTMLRendering.h"
#import "AwfulSettings.h"
#import "Awful-Swift.h"

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
    NSString *innerHTML = self.post.innerHTML;
    if (!innerHTML) return nil;
    HTMLDocument *document = [HTMLDocument documentWithString:innerHTML];
    RemoveSpoilerStylingAndEvents(document);
    RemoveEmptyEditedByParagraphs(document);
    UseHTML5VimeoPlayer(document);
    HighlightQuotesOfPostsByUserNamed(document, [AwfulSettings sharedSettings].username);
    if (![AwfulSettings sharedSettings].showImages) {
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
    return [AwfulSettings sharedSettings].showAvatars;
}

- (NSString *)roles
{
	return self.post.author.authorClasses;
}

- (NSString *)accessibilityRoles
{
    NSArray *unsortedRoles = [self.roles componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSMutableArray *accessibilityRoles = [unsortedRoles mutableCopy];
    const NSString * const rolesToSpokenRoles[] = {
        @"ik", @"internet knight",
        @"op", @"original poster",
    };
    for (NSUInteger i = 0, end = sizeof(rolesToSpokenRoles) / sizeof(*rolesToSpokenRoles); i < end; i += 2) {
        NSUInteger roleIndex = [accessibilityRoles indexOfObject:rolesToSpokenRoles[i]];
        if (roleIndex != NSNotFound) {
            [accessibilityRoles replaceObjectAtIndex:roleIndex withObject:rolesToSpokenRoles[i + 1]];
        }
    }
    return [accessibilityRoles componentsJoinedByString:@"; "];
}

- (BOOL)authorIsOP
{
    return [self.post.author isEqual:self.post.thread.author];
}

- (NSDateFormatter *)postDateFormat
{
    return [NSDateFormatter postDateFormatter];
}

- (NSDateFormatter *)regDateFormat
{
    return [NSDateFormatter regDateFormatter];
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.post valueForKey:key];
}

@dynamic author;
@dynamic beenSeen;
@dynamic postDate;
@dynamic postID;

@end
