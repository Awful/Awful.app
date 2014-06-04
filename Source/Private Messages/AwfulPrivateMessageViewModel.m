//  AwfulPrivateMessageViewModel.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageViewModel.h"
#import "AwfulDateFormatters.h"
#import "AwfulHTMLRendering.h"
#import "AwfulJavaScript.h"
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
    NSError *error;
    NSString *script = LoadJavaScriptResources(@[ @"zepto.min.js", @"common.js", @"private-message.js", ], &error);
    if (!script) {
        NSLog(@"%s error loading scripts: %@", __PRETTY_FUNCTION__, error);
    }
    return script;
}

- (NSNumber *)fontScalePercentage
{
    int percentage = [AwfulSettings settings].fontScale;
    if (percentage == 100) {
        return nil;
    } else {
        return @(percentage);
    }
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.privateMessage valueForKey:key];
}

@end
