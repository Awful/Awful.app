//
//  AwfulPostsView.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-29.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostsView.h"

@interface AwfulPostsView () <UIWebViewDelegate>

@property (weak, nonatomic) UIWebView *webView;

@end


@implementation AwfulPostsView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    UIWebView *webView = [[UIWebView alloc] initWithFrame:(CGRect){ .size = frame.size }];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.delegate = self;
    webView.dataDetectorTypes = UIDataDetectorTypeNone;
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    NSURL *postsViewURL = [thisBundle URLForResource:@"posts-view" withExtension:@"html"];
    NSError *error;
    NSString *html = [NSString stringWithContentsOfURL:postsViewURL
                                              encoding:NSUTF8StringEncoding
                                                 error:&error];
    if (!html) {
        NSLog(@"error loading html for %@: %@", [self class], error);
        return nil;
    }
    [webView loadHTMLString:html baseURL:[thisBundle resourceURL]];
    [self addSubview:webView];
    _webView = webView;
    return self;
}

- (void)reloadData
{
    NSMutableArray *posts = [NSMutableArray new];
    NSInteger numberOfPosts = [self.delegate numberOfPostsInPostsView:self];
    for (NSInteger i = 0; i < numberOfPosts; i++) {
        [posts addObject:[self.delegate postsView:self postAtIndex:i]];
    }
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:posts options:0 error:&error];
    if (!data) {
        NSLog(@"error serializing posts: %@", error);
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *js = [NSString stringWithFormat:@"Awful.posts(%@)", json];
    [self.webView stringByEvaluatingJavaScriptFromString:js];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self reloadData];
}

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
    navigationType:(UIWebViewNavigationType)navigationType
{
    if ([[[request URL] scheme] isEqualToString:@"x-objc"]) {
        [self bridgeJavaScriptToObjectiveCWithURL:[request URL]];
        return NO;
    }
    return YES;
}

- (void)bridgeJavaScriptToObjectiveCWithURL:(NSURL *)url
{
    if (![self.delegate respondsToSelector:@selector(methodSignatureForSelector:)]) return;
    NSArray *components = [url pathComponents];
    if ([components count] < 2) return;
    
    SEL selector = NSSelectorFromString(components[1]);
    if (![self.delegate respondsToSelector:selector]) return;
    
    NSArray *arguments;
    if ([components count] >= 3) {
        NSData *data = [components[2] dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error;
        arguments = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (!arguments) {
            NSLog(@"error deserializing arguments from JavaScript for method %@: %@",
                  NSStringFromSelector(selector), error);
        }
    }
    NSUInteger expectedArguments = [[components[1] componentsSeparatedByString:@":"] count] - 1;
    if ([arguments count] != expectedArguments) {
        NSLog(@"expecting %u arguments for %@, got %u instead",
              expectedArguments, NSStringFromSelector(selector), [arguments count]);
        return;
    }
    
    NSMethodSignature *signature = [self.delegate methodSignatureForSelector:selector];
    if (!signature) return;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    for (NSUInteger i = 0; i < [arguments count]; i++) {
        id arg = arguments[i];
        [invocation setArgument:&arg atIndex:i + 2];
    }
    [invocation invokeWithTarget:self.delegate];
}

@end
