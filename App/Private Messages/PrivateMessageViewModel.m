//  PrivateMessageViewModel.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "PrivateMessageViewModel.h"
#import "AwfulHTMLRendering.h"
#import "AwfulJavaScript.h"
#import "AwfulSettings.h"
#import "Awful-Swift.h"

@implementation PrivateMessageViewModel

- (instancetype)initWithPrivateMessage:(PrivateMessage *)privateMessage
{
    if ((self = [super init])) {
        _privateMessage = privateMessage;
    }
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

- (NSString *)fromUsername
{
    return self.privateMessage.fromUsername;
}

- (BOOL)showAvatars
{
    return [AwfulSettings sharedSettings].showAvatars;
}

- (NSString *)HTMLContents
{
    NSString *originalHTML = self.privateMessage.innerHTML;
    if (!originalHTML) return nil;
    
    HTMLDocument *document = [HTMLDocument documentWithString:originalHTML];
    RemoveSpoilerStylingAndEvents(document);
    UseHTML5VimeoPlayer(document);
    if (![AwfulSettings sharedSettings].showImages) {
        LinkifyNonSmileyImages(document);
    }
    return [document firstNodeMatchingSelector:@"body"].innerHTML;
}

- (NSDateFormatter *)regDateFormat
{
    return [NSDateFormatter regDateFormatter];
}

- (NSDateFormatter *)sentDateFormat
{
    return [NSDateFormatter postDateFormatter];
}

- (NSString *)javascript
{
    NSError *error;
    NSString *script = LoadJavaScriptResources(@[ @"WebViewJavascriptBridge.js.txt", @"zepto.min.js", @"common.js", @"private-message.js", ], &error);
    if (!script) {
        NSLog(@"%s error loading scripts: %@", __PRETTY_FUNCTION__, error);
    }
    return script;
}

- (NSNumber *)fontScalePercentage
{
    int percentage = [AwfulSettings sharedSettings].fontScale;
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

@dynamic from;
@dynamic messageID;
@dynamic seen;
@dynamic sentDate;

@end
