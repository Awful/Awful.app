//  UIPasteboard+AwfulStringyURLs.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIPasteboard+AwfulStringyURLs.h"
@import MobileCoreServices;

@implementation UIPasteboard (AwfulStringyURLs)

- (NSURL *)awful_URL
{
    return self.URL ?: [NSURL URLWithString:self.string];
}

- (void)awful_setURL:(NSURL *)URL
{
    self.items = @[ @{ (id)kUTTypeURL: URL,
                       (id)kUTTypePlainText: URL.absoluteString }];
}

@end
