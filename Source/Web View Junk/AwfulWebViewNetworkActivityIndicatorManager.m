//  AwfulWebViewNetworkActivityIndicatorManager.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulWebViewNetworkActivityIndicatorManager.h"

@interface AwfulWebViewNetworkActivityIndicatorManager ()

@property (assign, nonatomic) NSUInteger webViewActiveRequestCount;

@end

@implementation AwfulWebViewNetworkActivityIndicatorManager

- (void)dealloc
{
    self.webViewActiveRequestCount = 0;
}

- (id)initWithManager:(AFNetworkActivityIndicatorManager *)manager nextDelegate:(id <UIWebViewDelegate>)nextDelegate
{
    self = [super init];
    if (!self) return nil;
    
    _nextDelegate = nextDelegate;
    _manager = manager;
    
    return self;
}

- (id)initWithNextDelegate:(id<UIWebViewDelegate>)nextDelegate
{
    return [self initWithManager:[AFNetworkActivityIndicatorManager sharedManager] nextDelegate:nextDelegate];
}

- (id)init
{
    return [self initWithNextDelegate:nil];
}

- (void)setWebViewActiveRequestCount:(NSUInteger)webViewActiveRequestCount
{
    NSUInteger old = _webViewActiveRequestCount;
    _webViewActiveRequestCount = webViewActiveRequestCount;
    if (old == 0 && webViewActiveRequestCount > 0) {
        [self.manager incrementActivityCount];
    } else if (old > 0 && webViewActiveRequestCount == 0) {
        [self.manager decrementActivityCount];
    }
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    self.webViewActiveRequestCount++;
    
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate webViewDidStartLoad:webView];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    self.webViewActiveRequestCount--;
    
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate webViewDidFinishLoad:webView];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    self.webViewActiveRequestCount--;
    
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        [self.nextDelegate webView:webView didFailLoadWithError:error];
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    if ([self.nextDelegate respondsToSelector:_cmd]) {
        return [self.nextDelegate webView:webView shouldStartLoadWithRequest:request navigationType:navigationType];
    } else {
        return YES;
    }
}

@end
