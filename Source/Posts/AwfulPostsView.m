//  AwfulPostsView.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostsView.h"
#import "AwfulSettings.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <GRMustache.h>

@interface AwfulPostsView () <UIWebViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic) UIWebView *webView;

@property (nonatomic) BOOL didLoadHTML;
@property (nonatomic) BOOL hasLoaded;

@property (nonatomic) NSMutableIndexSet *toDelete;
@property (nonatomic) NSMutableIndexSet *toInsert;
@property (nonatomic) NSMutableIndexSet *toReload;

@property (copy, nonatomic) NSString *jumpToElementAfterLoading;

@end


@implementation AwfulPostsView
{
    BOOL _onceOnFirstLoad;
    BOOL _loadLinkifiedImagesOnFirstLoad;
    CGFloat _scrollToFractionOfContent;
}

- (void)dealloc
{
    [self.webView stopLoading];
    self.webView.delegate = nil;
}

- (id)initWithFrame:(CGRect)frame baseURL:(NSURL *)baseURL
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    
    _baseURL = baseURL;
    
    UIWebView *webView = [UIWebView awful_nativeFeelingWebView];
    webView.frame = (CGRect){ .size = frame.size };
    webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    webView.delegate = self;
    webView.backgroundColor = [UIColor clearColor];
    self.webView = webView;
    [self addSubview:self.webView];
    
    UITapGestureRecognizer *tap = [UITapGestureRecognizer new];
    tap.delegate = self;
    [tap addTarget:self action:@selector(didTapWebView:)];
    [self addGestureRecognizer:tap];
    UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
    longPress.delegate = self;
    [longPress addTarget:self action:@selector(didLongPressWebView:)];
    [self addGestureRecognizer:longPress];
    
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame baseURL:nil];
}

- (void)didTapWebView:(UITapGestureRecognizer *)tap
{
    if (tap.state == UIGestureRecognizerStateEnded)
    if ([self.delegate respondsToSelector:@selector(postsView:didReceiveSingleTapAtPoint:)]) {
        CGPoint location = [tap locationInView:self.webView];
        if (self.scrollView.contentOffset.y < 0) {
            location.y += self.scrollView.contentOffset.y;
        }
        [self.delegate postsView:self didReceiveSingleTapAtPoint:location];
    }
}

- (void)didLongPressWebView:(UILongPressGestureRecognizer *)longPress
{
    if (longPress.state == UIGestureRecognizerStateBegan)
    if ([self.delegate respondsToSelector:@selector(postsView:didReceiveLongTapAtPoint:)]) {
        CGPoint location = [longPress locationInView:self.webView];
        if (self.scrollView.contentOffset.y < 0) {
            location.y += self.scrollView.contentOffset.y;
        }
        [self.delegate postsView:self didReceiveLongTapAtPoint:location];
    }
}

- (void)reloadData
{
    NSMutableArray *posts = [NSMutableArray new];
    NSInteger numberOfPosts = [self.delegate numberOfPostsInPostsView:self];
    for (NSInteger i = 0; i < numberOfPosts; i++) {
        [posts addObject:[self.delegate postsView:self renderedPostAtIndex:i]];
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
    [self evalJavaScript:@"Awful.ad(%@)", JSONizeValue(ad)];
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
    NSString *post = [self.delegate postsView:self renderedPostAtIndex:index];
    [self evalJavaScript:@"Awful.insertPost(%@, %d)", JSONizeValue(post), index];
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
    NSString *post = [self.delegate postsView:self renderedPostAtIndex:index];
    [self evalJavaScript:@"Awful.post(%d, %@)", index, JSONizeValue(post)];
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

static NSString * JSONizeValue(id value)
{
    // Foundation's JSON serializer only does arrays and objects at the top level.
    return [JSONize(@[ value ?: [NSNull null] ]) stringByAppendingString:@"[0]"];
}

static NSString * JSONizeBool(BOOL aBool)
{
    return aBool ? @"true" : @"false";
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
        [self evalJavaScript:@"window.location.hash = '#' + %@", JSONizeValue(elementID)];
    }
}

- (NSString *)evalJavaScript:(NSString *)script, ...
{
    va_list args;
    va_start(args, script);
    NSMutableString *js = [[NSMutableString alloc] initWithFormat:script arguments:args];
    va_end(args);
    
    // JavaScript considers U+2028 and U+2029 "line terminators" which are not allowed in string literals, but JSON does not require them to be escaped.
    [js replaceOccurrencesOfString:@"\u2028" withString:@"\\u2028" options:0 range:NSMakeRange(0, js.length)];
    [js replaceOccurrencesOfString:@"\u2029" withString:@"\\u2029" options:0 range:NSMakeRange(0, js.length)];
    
    return [self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)setStylesheet:(NSString *)stylesheet
{
    if (_stylesheet == stylesheet) return;
    _stylesheet = [stylesheet copy];
    [self updateStylesheet];
}

- (void)loadHTML
{
    NSURL *scriptURL = [[NSBundle mainBundle] URLForResource:@"combined" withExtension:@"js"];
    NSError *error;
    NSString *script = [NSString stringWithContentsOfURL:scriptURL encoding:NSUTF8StringEncoding error:&error];
    if (!script) {
        NSLog(@"%s error loading script from %@: %@", __PRETTY_FUNCTION__, scriptURL, error);
        script = @"";
    }
    NSString *idiom = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"ipad" : @"iphone";
    NSDictionary *context = @{ @"userInterfaceIdiom": idiom,
                               @"stylesheet": self.stylesheet ?: @"",
                               @"script": script };
    NSString *HTML = [GRMustacheTemplate renderObject:context fromResource:@"PostsView" bundle:nil error:&error];
    if (!HTML) {
        NSLog(@"%s error loading posts view HTML: %@", __PRETTY_FUNCTION__, error);
    }
    [self.webView loadHTMLString:HTML baseURL:self.baseURL];
    self.didLoadHTML = YES;
    [self updateFontScale];
}

- (void)updateStylesheet
{
    if (self.didLoadHTML) {
        [self evalJavaScript:@"Awful.stylesheet(%@)", JSONizeValue(self.stylesheet ?: @"")];
    } else {
        [self loadHTML];
    }
}

- (void)setShowAvatars:(BOOL)showAvatars
{
    if (_showAvatars == showAvatars) return;
    _showAvatars = showAvatars;
    [self updateShowAvatars];
}

- (void)setFontScale:(int)fontScale
{
    if (_fontScale == fontScale) return;
    _fontScale = fontScale;
    [self updateFontScale];
}

- (void)updateFontScale
{
    [self evalJavaScript:@"Awful.setFontScale(%d)", self.fontScale];
}

- (void)updateShowAvatars
{
    [self evalJavaScript:@"Awful.showAvatars(%@)", JSONizeBool(self.showAvatars)];
}

- (void)loadLinkifiedImages
{
    _loadLinkifiedImagesOnFirstLoad = YES;
    [self evalJavaScript:@"Awful.loadLinkifiedImages()"];
}

- (void)setHighlightMentionUsername:(NSString *)highlightMentionUsername
{
    if (_highlightMentionUsername == highlightMentionUsername) return;
    _highlightMentionUsername = [highlightMentionUsername copy];
    [self updateHighlightMentionUsername];
}

- (void)updateHighlightMentionUsername
{
    [self evalJavaScript:@"Awful.highlightMentionUsername(%@)",
     JSONizeValue(self.highlightMentionUsername)];
}

- (void)setLastReadPostID:(NSString *)postID
{
    [self evalJavaScript:@"Awful.markReadUpToPostWithID(%@)", JSONizeValue(postID)];
}

- (CGFloat)scrolledFractionOfContent
{
    return [[self evalJavaScript:@"document.body.scrollTop / document.body.scrollHeight"] floatValue];
}

- (void)scrollToFractionOfContent:(CGFloat)fraction
{
    _scrollToFractionOfContent = fraction;
    [self updateScrollToFractionOfContent];
}

- (void)updateScrollToFractionOfContent
{
    if (_onceOnFirstLoad) {
        [self evalJavaScript:@"window.scroll(0, document.body.scrollHeight * %g)", _scrollToFractionOfContent];
    }
}

- (UIScrollView *)scrollView
{
    return self.webView.scrollView;
}

- (void)setEndMessage:(NSString *)endMessage
{
    if (_endMessage == endMessage) return;
    _endMessage = [endMessage copy];
    [self updateEndMessage];
}

- (void)updateEndMessage
{
    [self evalJavaScript:@"Awful.endMessage(%@)", JSONizeValue(self.endMessage)];
}

typedef struct WebViewPoint
{
    NSInteger x;
    NSInteger y;
} WebViewPoint;

static WebViewPoint WebViewPointForPointInWebView(CGPoint point, UIWebView *webView)
{
    CGPoint offset = webView.scrollView.contentOffset;
    if (offset.x > 0) {
        offset.x = 0;
    }
    if (offset.y > 0) {
        offset.y = 0;
    }
    return (WebViewPoint){
        // As of iOS 7, UIWebView takes its scroll view's content inset into account when calculating element positions.
        .x = point.x - webView.scrollView.contentInset.left - offset.x,
        .y = point.y - webView.scrollView.contentInset.top - offset.y,
    };
}

- (NSInteger)indexOfPostWithActionButtonAtPoint:(CGPoint)point rect:(CGRect *)rect
{
    WebViewPoint webViewPoint = WebViewPointForPointInWebView(point, self.webView);
    NSDictionary *postInfo = [self evalJavaScriptWithJSONResponse:@"Awful.postWithButtonForPoint(%d, %d)",
                              webViewPoint.x, webViewPoint.y];
    if (![postInfo isKindOfClass:[NSDictionary class]]) return NSNotFound;
    if (rect) {
        *rect = [self rectOfElementWithRectDictionary:postInfo[@"rect"]];
    }
    return [postInfo[@"postIndex"] integerValue];
}

- (NSInteger)indexOfPostWithUserNameAtPoint:(CGPoint)point rect:(CGRect *)rect
{
    WebViewPoint webViewPoint = WebViewPointForPointInWebView(point, self.webView);
	NSDictionary *postInfo = [self evalJavaScriptWithJSONResponse:@"Awful.postWithUserNameForPoint(%d, %d)",
                              webViewPoint.x, webViewPoint.y];
	if (![postInfo isKindOfClass:[NSDictionary class]]) return NSNotFound;
	if (rect) {
		*rect = [self rectOfElementWithRectDictionary:postInfo[@"rect"]];
	}
	return [postInfo[@"postIndex"] integerValue];
}

- (id)evalJavaScriptWithJSONResponse:(NSString *)script, ...
{
    va_list args;
    va_start(args, script);
    NSString *js = [[NSString alloc] initWithFormat:script arguments:args];
    va_end(args);
    NSString *response = [self.webView stringByEvaluatingJavaScriptFromString:js];
    // No point recording the error; a JSON parse error simply means "no response".
    return [NSJSONSerialization JSONObjectWithData:[response dataUsingEncoding:NSUTF8StringEncoding]
                                           options:0
                                             error:nil];
}

- (CGRect)rectOfElementWithRectDictionary:(NSDictionary *)rectDict
{
    CGRect rect = CGRectMake([rectDict[@"left"] floatValue], [rectDict[@"top"] floatValue],
                             [rectDict[@"width"] floatValue], [rectDict[@"height"] floatValue]);
    UIEdgeInsets insets = self.scrollView.contentInset;
    return CGRectOffset(rect, insets.left, insets.top);
}

- (NSURL *)URLOfSpoiledImageForPoint:(CGPoint)point
{
    WebViewPoint webViewPoint = WebViewPointForPointInWebView(point, self.webView);
    NSDictionary *imageInfo = [self evalJavaScriptWithJSONResponse:@"Awful.spoiledImageInPostForPoint(%d, %d)",
                               webViewPoint.x, webViewPoint.y];
    if ([imageInfo isKindOfClass:[NSDictionary class]]) {
        return [NSURL awful_URLWithString:imageInfo[@"url"]];
    } else {
        return nil;
    }
}

- (NSURL *)URLOfSpoiledLinkForPoint:(CGPoint)point rect:(CGRect *)rect
{
    WebViewPoint webViewPoint = WebViewPointForPointInWebView(point, self.webView);
    NSDictionary *linkInfo = [self evalJavaScriptWithJSONResponse:@"Awful.spoiledLinkInPostForPoint(%d, %d)",
                              webViewPoint.x, webViewPoint.y];
    if (![linkInfo isKindOfClass:[NSDictionary class]]) return nil;
    if (rect) {
        *rect = [self rectOfElementWithRectDictionary:linkInfo[@"rect"]];
    }
    return [NSURL awful_URLWithString:linkInfo[@"url"]];
}

- (NSURL *)URLOfSpoiledVideoForPoint:(CGPoint)point rect:(out CGRect *)rect
{
    WebViewPoint webViewPoint = WebViewPointForPointInWebView(point, self.webView);
    NSDictionary *videoInfo = [self evalJavaScriptWithJSONResponse:@"Awful.spoiledVideoInPostForPoint(%d, %d)",
                               webViewPoint.x, webViewPoint.y];
    if (![videoInfo isKindOfClass:[NSDictionary class]]) return nil;
    if (rect) {
        *rect = [self rectOfElementWithRectDictionary:videoInfo[@"rect"]];
    }
    return [NSURL awful_URLWithString:videoInfo[@"url"]];
}

- (CGRect)rectOfHeaderForPostWithID:(NSString *)postID
{
    NSDictionary *rectDict = [self evalJavaScriptWithJSONResponse:@"Awful.headerForPostWithID(%@)", postID];
    return [self rectOfElementWithRectDictionary:rectDict];
}

- (CGRect)rectOfFooterForPostWithID:(NSString *)postID
{
    NSDictionary *rectDict = [self evalJavaScriptWithJSONResponse:@"Awful.footerForPostWithID(%@)", postID];
    return [self rectOfElementWithRectDictionary:rectDict];
}

- (CGRect)rectOfActionButtonForPostWithID:(NSString *)postID
{
    NSDictionary *rectDict = [self evalJavaScriptWithJSONResponse:@"Awful.actionButtonForPostWithID(%@)", postID];
    return [self rectOfElementWithRectDictionary:rectDict];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!_onceOnFirstLoad) {
        _onceOnFirstLoad = YES;
        [self updateShowAvatars];
        [self updateFontScale];
        if (_loadLinkifiedImagesOnFirstLoad) {
            [self loadLinkifiedImages];
        }
        [self updateHighlightMentionUsername];
        [self updateEndMessage];
        self.hasLoaded = YES;
        [self reloadData];
        if (self.jumpToElementAfterLoading) {
            [self jumpToElementWithID:self.jumpToElementAfterLoading];
            self.jumpToElementAfterLoading = nil;
        } else if (_scrollToFractionOfContent > 0) {
            [self updateScrollToFractionOfContent];
        }
    }
}

- (BOOL)webView:(UIWebView *)webView
    shouldStartLoadWithRequest:(NSURLRequest *)request
    navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *url = request.URL;
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        if ([self.delegate respondsToSelector:@selector(postsView:willFollowLinkToURL:)]) {
            [self.delegate postsView:self willFollowLinkToURL:url];
        }
        return NO;
    } else if ([url.host hasSuffix:@"www.youtube.com"] && [url.path hasPrefix:@"/watch"]) {
        // Prevent YouTube embeds from taking over the whole frame. This would happen if you tap
        // the title of the video in the embed.
        return NO;
    }
    return YES;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return !self.scrollView.dragging;
}

@end

