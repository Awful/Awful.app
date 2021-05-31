//  SmilieWebArchive.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieWebArchive.h"

@interface SmilieWebArchive ()

@property (copy, nonatomic) NSDictionary *plist;
@property (copy, nonatomic) NSDictionary *subresources;

@end

@implementation SmilieWebArchive

@synthesize mainFrameHTML = _mainFrameHTML;

- (instancetype)initWithURL:(NSURL *)URL
{
    if ((self = [super init])) {
        _URL = URL;
    }
    return self;
}

- (NSDictionary *)plist
{
    if (!_plist) {
        NSInputStream *stream = [NSInputStream inputStreamWithURL:self.URL];
        [stream open];
        NSError *error;
        _plist = [NSPropertyListSerialization propertyListWithStream:stream options:0 format:nil error:&error];
        if (!_plist) {
            NSLog(@"%s error loading plist from %@: %@", __PRETTY_FUNCTION__, self.URL, error);
        }
    }
    return _plist;
}

- (NSDictionary *)subresources
{
    if (!_subresources) {
        NSMutableDictionary *subresources = [NSMutableDictionary new];
        for (NSDictionary *resource in self.plist[@"WebSubresources"]) {
            subresources[resource[@"WebResourceURL"]] = resource;
        }
        _subresources = subresources;
    }
    return _subresources;
}

- (NSString *)mainFrameHTML
{
    if (!_mainFrameHTML) {
        NSDictionary *mainResource = self.plist[@"WebMainResource"];
        NSString *textEncodingName = mainResource[@"WebResourceTextEncodingName"];
        CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)textEncodingName);
        NSStringEncoding encoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
        _mainFrameHTML = [[NSString alloc] initWithData:mainResource[@"WebResourceData"] encoding:encoding];
    }
    return _mainFrameHTML;
}

- (NSData *)dataForSubresourceWithURL:(NSURL *)subresourceURL
{
    NSDictionary *resource = self.subresources[subresourceURL.absoluteString];
    return resource[@"WebResourceData"];
}

@end
