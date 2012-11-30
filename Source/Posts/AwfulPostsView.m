//
//  AwfulPostsView.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-29.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostsView.h"

@interface AwfulPostsView () <UIWebViewDelegate>

@property (nonatomic) UIWebView *webView;

@property (nonatomic) BOOL hasLoaded;

@property (nonatomic) NSMutableIndexSet *toDelete;

@property (nonatomic) NSMutableIndexSet *toInsert;

@property (nonatomic) NSMutableIndexSet *toReload;

@property (copy, nonatomic) NSString *jumpToElementAfterLoading;

@end


@implementation AwfulPostsView
{
    dispatch_once_t _onceOnFirstLoad;
}

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    UIWebView *webView = [[UIWebView alloc] initWithFrame:(CGRect){ .size = frame.size }];
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.delegate = self;
    webView.dataDetectorTypes = UIDataDetectorTypeNone;
    webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = NO;
    RemoveShadowFromAboveAndBelowWebView(webView);
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
    _webView = webView;
    return self;
}

static void RemoveShadowFromAboveAndBelowWebView(UIWebView *webView)
{
    for (UIView *view in [webView.scrollView subviews]) {
        if ([view isKindOfClass:[UIImageView class]]) {
            view.hidden = YES;
        }
    }
}

- (void)reloadData
{
    NSMutableArray *posts = [NSMutableArray new];
    NSInteger numberOfPosts = [self.delegate numberOfPostsInPostsView:self];
    for (NSInteger i = 0; i < numberOfPosts; i++) {
        [posts addObject:[self.delegate postsView:self postAtIndex:i]];
    }
    [self evalJavaScript:@"Awful.posts(%@)", JSONize(posts)];
    [self reloadAdvertisementHTML];
}

- (void)reloadAdvertisementHTML
{
    NSString *ad = @"";
    if ([self.delegate respondsToSelector:@selector(advertisementHTMLForPostsView:)]) {
        ad = [self.delegate advertisementHTMLForPostsView:self];
        if ([ad length] == 0) ad = @"";
    }
    // Foundation's JSON serializer only does arrays and objects at the top level.
    [self evalJavaScript:@"Awful.ad(%@[0])", JSONize(@[ ad ])];
}

- (void)beginUpdates
{
    self.toDelete = [NSMutableIndexSet new];
    self.toInsert = [NSMutableIndexSet new];
    self.toReload = [NSMutableIndexSet new];
}

- (void)insertPostAtIndex:(NSInteger)index
{
    if (self.toInsert) {
        [self.toInsert addIndex:index];
        return;
    }
    NSDictionary *post = [self.delegate postsView:self postAtIndex:index];
    [self evalJavaScript:@"Awful.insertPost(%@, %d)", JSONize(post), index];
}

- (void)deletePostAtIndex:(NSInteger)index
{
    if (self.toDelete) {
        [self.toDelete addIndex:index];
        return;
    }
    [self evalJavaScript:@"Awful.deletePost(%d)", index];
}

- (void)reloadPostAtIndex:(NSInteger)index
{
    if (self.toReload) {
        [self.toReload addIndex:index];
        return;
    }
    NSDictionary *post = [self.delegate postsView:self postAtIndex:index];
    [self evalJavaScript:@"Awful.post(%d, %@)", index, JSONize(post)];
}

- (void)endUpdates
{
    NSIndexSet *toDelete = self.toDelete;
    self.toDelete = nil;
    [toDelete enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *_) {
        [self deletePostAtIndex:i];
    }];
    NSIndexSet *toInsert = self.toInsert;
    self.toInsert = nil;
    [toInsert enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *_) {
        [self insertPostAtIndex:i];
    }];
    NSIndexSet *toReload = self.toReload;
    self.toReload = nil;
    [toReload enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *_) {
        [self reloadPostAtIndex:i];
    }];
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

- (void)clearAllPosts
{
    [self evalJavaScript:@"Awful.posts([])"];
}

- (void)jumpToElementWithID:(NSString *)elementID
{
    if (!self.hasLoaded) {
        self.jumpToElementAfterLoading = elementID;
        return;
    }
    // Clear the hash first in case we're jumping again to the same place as last time.
    [self evalJavaScript:@"window.location.hash = ''"];
    if ([elementID length] > 0) {
        [self evalJavaScript:@"window.location.hash = '#' + %@[0]", JSONize(@[ elementID ])];
    }
}

- (NSString *)evalJavaScript:(NSString *)script, ...
{
    va_list args;
    va_start(args, script);
    NSString *js = [[NSString alloc] initWithFormat:script arguments:args];
    va_end(args);
    return [self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)setStylesheetURL:(NSURL *)stylesheetURL
{
    if (_stylesheetURL == stylesheetURL) return;
    _stylesheetURL = stylesheetURL;
    [self updateStylesheetURL];
}

- (void)updateStylesheetURL
{
    NSString *url = [self.stylesheetURL absoluteString];
    [self evalJavaScript:@"Awful.stylesheetURL('%@')", url ? url : @""];
}

- (void)setDark:(BOOL)dark
{
    if (_dark == dark) return;
    _dark = dark;
    [self updateDark];
}

- (void)updateDark
{
    [self evalJavaScript:@"Awful.dark(%@)", self.dark ? @"true" : @"false"];
}

- (void)setShowAvatars:(BOOL)showAvatars
{
    if (_showAvatars == showAvatars) return;
    _showAvatars = showAvatars;
    [self updateShowAvatars];
}

- (void)updateShowAvatars
{
    [self evalJavaScript:@"Awful.showAvatars(%@)", self.showAvatars ? @"true" : @"false"];
}

- (void)setShowImages:(BOOL)showImages
{
    if (_showImages == showImages) return;
    _showImages = showImages;
    [self updateShowImages];
}

- (void)updateShowImages
{
    [self evalJavaScript:@"Awful.showImages(%@)", self.showImages ? @"true" : @"false"];
}

- (void)setHighlightQuoteUsername:(NSString *)highlightQuoteUsername
{
    if (_highlightQuoteUsername == highlightQuoteUsername) return;
    _highlightQuoteUsername = [highlightQuoteUsername copy];
    [self updateHighlightQuoteUsername];
}

- (void)updateHighlightQuoteUsername
{
    NSString *json = JSONize(@[ self.highlightQuoteUsername ?: [NSNull null] ]);
    [self evalJavaScript:@"Awful.highlightQuoteUsername(%@[0])", json];
}

- (void)setHighlightMentionUsername:(NSString *)highlightMentionUsername
{
    if (_highlightMentionUsername == highlightMentionUsername) return;
    _highlightMentionUsername = [highlightMentionUsername copy];
    [self updateHighlightMentionUsername];
}

- (void)updateHighlightMentionUsername
{
    NSString *json = JSONize(@[ self.highlightMentionUsername ?: [NSNull null] ]);
    [self evalJavaScript:@"Awful.highlightMentionUsername(%@[0])", json];
}

- (UIScrollView *)scrollView
{
    return self.webView.scrollView;
}

- (void)setLoadingMessage:(NSString *)loadingMessage
{
    if (_loadingMessage == loadingMessage) return;
    _loadingMessage = [loadingMessage copy];
    [self updateLoadingMessage];
}

- (void)updateLoadingMessage
{
    NSString *json = JSONize(@[ self.loadingMessage ?: [NSNull null] ]);
    [self evalJavaScript:@"Awful.loading(%@[0])", json];
    if (self.loadingMessage) {
        self.scrollView.contentOffset = CGPointZero;
        self.scrollView.scrollEnabled = NO;
    } else {
        self.scrollView.scrollEnabled = YES;
    }
}

- (void)setEndMessage:(NSString *)endMessage
{
    if (_endMessage == endMessage) return;
    _endMessage = [endMessage copy];
    [self updateEndMessage];
}

- (void)updateEndMessage
{
    NSString *json = JSONize(@[ self.endMessage ?: [NSNull null] ]);
    [self evalJavaScript:@"Awful.endMessage(%@[0])", json];
}

- (void)firstStylesheetDidLoad
{
    self.webView.frame = (CGRect){ .size = self.bounds.size };
    [self addSubview:self.webView];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    dispatch_once(&_onceOnFirstLoad, ^{
        [self updateStylesheetURL];
        [self updateDark];
        [self updateShowAvatars];
        [self updateShowImages];
        [self updateLoadingMessage];
        [self updateHighlightQuoteUsername];
        [self updateHighlightMentionUsername];
        [self updateEndMessage];
        self.hasLoaded = YES;
        [self reloadData];
        if (self.jumpToElementAfterLoading) {
            [self jumpToElementWithID:self.jumpToElementAfterLoading];
            self.jumpToElementAfterLoading = nil;
        }
    });
}

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
    navigationType:(UIWebViewNavigationType)navigationType
{
    if ([[[request URL] scheme] isEqualToString:@"x-objc"]) {
        [self bridgeJavaScriptToObjectiveCWithURL:[request URL]];
        return NO;
    } else if ([[[request URL] scheme] isEqualToString:@"x-objc-postsview"]) {
        [self bridgeJavaScriptToObjectiveCOnSelfWithURL:[request URL]];
    } else if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        if ([self.delegate respondsToSelector:@selector(postsView:didTapLinkToURL:)]) {
            [self.delegate postsView:self didTapLinkToURL:[request URL]];
        }
        return NO;
    }
    return YES;
}

- (void)bridgeJavaScriptToObjectiveCWithURL:(NSURL *)url
{
    if (![self.delegate respondsToSelector:@selector(whitelistedSelectorsForPostsView:)]) return;
    NSArray *whitelist = [self.delegate whitelistedSelectorsForPostsView:self];
    InvokeBridgedMethodWithURLAndTarget(url, self.delegate, whitelist);
}

- (void)bridgeJavaScriptToObjectiveCOnSelfWithURL:(NSURL *)url
{
    NSArray *whitelist = @[ @"firstStylesheetDidLoad" ];
    InvokeBridgedMethodWithURLAndTarget(url, self, whitelist);
}

static void InvokeBridgedMethodWithURLAndTarget(NSURL *url, id target, NSArray *whitelist)
{
    NSArray *components = [url pathComponents];
    if ([components count] < 2) return;
    
    if (![whitelist containsObject:components[1]]) return;
    SEL selector = NSSelectorFromString(components[1]);
    if (![target respondsToSelector:selector]) return;
    
    NSArray *arguments;
    if ([components count] >= 3) {
        NSArray *args = [components subarrayWithRange:NSMakeRange(2, [components count] - 2)];
        NSString *stringData = [args componentsJoinedByString:@"/"];
        NSData *data = [stringData dataUsingEncoding:NSUTF8StringEncoding];
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
    
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    if (!signature) return;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setSelector:selector];
    for (NSUInteger i = 0; i < [arguments count]; i++) {
        id arg = arguments[i];
        [invocation setArgument:&arg atIndex:i + 2];
    }
    [invocation invokeWithTarget:target];
}

@end
