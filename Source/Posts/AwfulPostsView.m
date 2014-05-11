//  AwfulPostsView.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsView.h"
#import "AwfulJavaScript.h"
#import "AwfulSettings.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <GRMustache.h>
#import <WebViewJavascriptBridge.h>

@interface AwfulPostsView () <UIWebViewDelegate>

@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) WebViewJavascriptBridge *webViewJavaScriptBridge;

@property (nonatomic) BOOL didLoadHTML;
@property (nonatomic) BOOL hasLoaded;

@property (copy, nonatomic) NSString *jumpToElementAfterLoading;

@end


@implementation AwfulPostsView
{
    BOOL _didFinishLoadingOnce;
    CGFloat _scrollToFractionOfContent;
}

- (id)initWithFrame:(CGRect)frame baseURL:(NSURL *)baseURL
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _baseURL = baseURL;
    
    UIWebView *webView = [UIWebView awful_nativeFeelingWebView];
    webView.frame = (CGRect){ .size = frame.size };
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.backgroundColor = [UIColor clearColor];
    _webView = webView;
    [self addSubview:_webView];
    
    _webViewJavaScriptBridge = [WebViewJavascriptBridge bridgeForWebView:webView webViewDelegate:self handler:^(id data, WVJBResponseCallback _) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, data);
    }];
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame baseURL:nil];
}

- (void)reloadData
{
    _didFinishLoadingOnce = NO;
    NSString *HTML = [self.delegate HTMLForPostsView:self];
    [self.webView loadHTMLString:HTML baseURL:self.baseURL];
    self.didLoadHTML = YES;
}

static NSString * JSONize(id obj)
{
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:obj options:0 error:&error];
    if (!data) {
        NSLog(@"error serializing %@: %@", obj, error);
        return nil;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

static NSString * JSONizeValue(id value)
{
    // Foundation's JSON serializer only does arrays and objects at the top level.
    return [JSONize(@[ value ?: [NSNull null] ]) stringByAppendingString:@"[0]"];
}

- (void)jumpToElementWithID:(NSString *)elementID
{
    if (!self.hasLoaded) {
        self.jumpToElementAfterLoading = elementID;
        return;
    }
    // Clear the hash first in case we're jumping again to the same place as last time.
    [self.webView awful_evalJavaScript:@"window.location.hash = ''; window.location.hash = '#' + %@", JSONizeValue(elementID ?: @"")];
}

- (CGFloat)scrolledFractionOfContent
{
    return self.webView.awful_fractionalContentOffset;
}

- (void)scrollToFractionOfContent:(CGFloat)fraction
{
    if (_didFinishLoadingOnce) {
        self.webView.awful_fractionalContentOffset = fraction;
        _scrollToFractionOfContent = 0;
    } else {
        _scrollToFractionOfContent = fraction;
    }
}

- (UIScrollView *)scrollView
{
    return self.webView.scrollView;
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!_didFinishLoadingOnce) {
        _didFinishLoadingOnce = YES;
        self.hasLoaded = YES;
        if (self.jumpToElementAfterLoading) {
            [self jumpToElementWithID:self.jumpToElementAfterLoading];
            self.jumpToElementAfterLoading = nil;
        } else if (_scrollToFractionOfContent > 0) {
            webView.awful_fractionalContentOffset = _scrollToFractionOfContent;
            _scrollToFractionOfContent = 0;
        }
    }
}

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
    navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *URL = [NSURL URLWithString:request.URL.absoluteString relativeToURL:self.baseURL];
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        [self.delegate postsView:self willFollowLinkToURL:URL];
        return NO;
    } else if ([URL.host hasSuffix:@"www.youtube.com"] && [URL.path hasPrefix:@"/watch"]) {
        // Prevent YouTube embeds from taking over the whole frame. This would happen if you tap
        // the title of the video in the embed.
        return NO;
    }
    return YES;
}

@end
