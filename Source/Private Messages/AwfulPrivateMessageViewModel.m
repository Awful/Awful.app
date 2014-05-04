//  AwfulPrivateMessageViewModel.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageViewModel.h"
#import "AwfulDateFormatters.h"
#import "AwfulHTMLRendering.h"
#import "AwfulSettings.h"

@implementation AwfulPrivateMessageViewModel

- (id)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage
{
    self = [super init];
    if (!self) return nil;
    
    _privateMessage = privateMessage;
    
    return self;
}

- (NSString *)userInterfaceIdiom
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"ipad" : @"iphone";
}

- (NSURL *)visibleAvatarURL
{
    return [self showAvatars] ? self.privateMessage.from.avatarURL : nil;
}

- (NSURL *)hiddenAvatarURL
{
    return [self showAvatars] ? nil : self.privateMessage.from.avatarURL;
}

- (BOOL)showAvatars
{
    return [AwfulSettings settings].showAvatars;
}

- (NSString *)HTMLContents
{
    NSString *originalHTML = self.privateMessage.innerHTML;
    if (!originalHTML) return nil;
    
    HTMLDocument *document = [HTMLDocument documentWithString:originalHTML];
    RemoveSpoilerStylingAndEvents(document);
    UseHTML5VimeoPlayer(document);
    if (![AwfulSettings settings].showImages) {
        LinkifyNonSmileyImages(document);
    }
    return [document firstNodeMatchingSelector:@"body"].innerHTML;
}

- (NSDateFormatter *)regDateFormat
{
    return [AwfulDateFormatters regDateFormatter];
}

- (NSDateFormatter *)sentDateFormat
{
    return [AwfulDateFormatters postDateFormatter];
}

- (NSString *)javascript
{
    static __unsafe_unretained NSString *scriptFilenames[] = {
        @"zepto.min.js",
        @"fastclick.js",
        @"private-message.js",
        @"spoilers.js",
    };
    NSMutableArray *scripts = [NSMutableArray new];
    for (NSUInteger i = 0, end = sizeof(scriptFilenames) / sizeof(*scriptFilenames); i < end; i++) {
        NSString *filename = scriptFilenames[i];
        NSURL *URL = [[NSBundle mainBundle] URLForResource:filename withExtension:nil];
        NSError *error;
        NSString *script = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
        if (!script) {
            NSLog(@"%s error loading %@ from %@: %@", __PRETTY_FUNCTION__, filename, URL, error);
            return nil;
        }
        [scripts addObject:script];
    }
    return [scripts componentsJoinedByString:@"\n\n"];
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.privateMessage valueForKey:key];
}

@end
