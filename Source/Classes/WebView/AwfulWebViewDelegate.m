//
//  AwfulWebViewDelegate.m
//  Awful
//
//  Created by Nolan Waite on 12-05-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulWebViewDelegate.h"

@interface AwfulWebViewDelegateWrapper () <UIWebViewDelegate>

@property (weak) id <AwfulWebViewDelegate, NSObject> delegate;

@end

@implementation AwfulWebViewDelegateWrapper

+ (id <UIWebViewDelegate>)delegateWrappingDelegate:(id <AwfulWebViewDelegate>)delegate
{
    return [[self alloc] initWithDelegate:delegate];
}

- (id)initWithDelegate:(id <AwfulWebViewDelegate>)delegate
{
    self = [super init];
    if (self)
    {
        self.delegate = delegate;
    }
    return self;
}

@synthesize delegate = _delegate;

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
    NSString *urlString = request.URL.absoluteString;
    if ([urlString hasPrefix:@"awful-log:"])
    {
        NSLog(@"A script in %@ said\n%@",
              webView, [urlString substringFromIndex:@"awful-log:".length]);
        return NO;
    }
    if ([request.URL.scheme isEqualToString:@"awful-js"])
    {
        NSString *action = request.URL.host;
        NSString *infoDictionaryID = request.URL.lastPathComponent;
        NSDictionary *infoDictionary;
        if (infoDictionaryID.length > 0)
        {
            NSString *js = [NSString stringWithFormat:@"Awful.receive(%@)", infoDictionaryID];
            NSString *json = [webView stringByEvaluatingJavaScriptFromString:js];
            NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
            NSError *error;
            infoDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (!infoDictionary)
            {
                NSLog(@"A script in %@ passed an invalid info dictionary: %@\nerror: %@",
                      webView, js, error);
            }
        }
        [self.delegate webView:webView pageDidRequestAction:action infoDictionary:infoDictionary];
        return NO;
    }
    if ([self.delegate respondsToSelector:_cmd])
    {
        return [self.delegate webView:webView
           shouldStartLoadWithRequest:request
                       navigationType:navigationType];
    }
    return YES;
}

#pragma mark - Forwarding to delegate

- (id)forwardingTargetForSelector:(SEL)selector
{
    if ([self.delegate respondsToSelector:selector])
        return self.delegate;
    else
        return [super forwardingTargetForSelector:selector];
}

@end
