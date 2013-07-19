//
//  AwfulPostsView.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulPostsView.h"
#import "AwfulSettings.h"
#import "NSFileManager+UserDirectories.h"
#import "NSURL+Punycode.h"

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
    webView.scalesPageToFit = YES;
    webView.backgroundColor = [UIColor clearColor];
    webView.opaque = NO;
    RemoveShadowFromAboveAndBelowWebView(webView);
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

- (void)dealloc
{
    self.webView.delegate = nil;
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
    NSString *js = [[NSString alloc] initWithFormat:script arguments:args];
    va_end(args);
    return [self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)setStylesheetURL:(NSURL *)stylesheetURL
{
    if ([_stylesheetURL isEqual:stylesheetURL]) return;
    _stylesheetURL = stylesheetURL;
    [self updateStylesheetURL];
}

- (void)loadHTML
{
    NSBundle *thisBundle = [NSBundle bundleForClass:[self class]];
    NSURL *postsViewURL = [thisBundle URLForResource:@"posts-view" withExtension:@"html"];
    NSError *error;
    NSString *html = [NSString stringWithContentsOfURL:postsViewURL
                                              encoding:NSUTF8StringEncoding
                                                 error:&error];
    if (!html) {
        NSLog(@"error loading html for %@: %@", [self class], error);
        return;
    }
    NSString *css = @"";
    if (self.stylesheetURL) {
        css = [NSString stringWithContentsOfURL:self.stylesheetURL
                                       encoding:NSUTF8StringEncoding
                                          error:&error];
        if (!css) {
            NSLog(@"error loading CSS from %@: %@", self.stylesheetURL, error);
            return;
        }
    }
    [self.webView loadHTMLString:[NSString stringWithFormat:html, css]
                         baseURL:[thisBundle resourceURL]];
    self.didLoadHTML = YES;
}

- (void)updateStylesheetURL
{
    if (self.didLoadHTML) {
        NSString *url = [self.stylesheetURL absoluteString];
        [self evalJavaScript:@"Awful.stylesheetURL(%@)", JSONizeValue(url ?: @"")];
    } else {
        [self loadHTML];
    }
}

- (void)setDark:(BOOL)dark
{
    if (_dark == dark) return;
    _dark = dark;
    [self updateDark];
}

- (void)updateDark
{
    [self evalJavaScript:@"Awful.dark(%@)", JSONizeBool(self.dark)];
}

- (void)setShowAvatars:(BOOL)showAvatars
{
    if (_showAvatars == showAvatars) return;
    _showAvatars = showAvatars;
    [self updateShowAvatars];
}

- (void)updateShowAvatars
{
    [self evalJavaScript:@"Awful.showAvatars(%@)", JSONizeBool(self.showAvatars)];
}

- (void)setShowImages:(BOOL)showImages
{
    if (_showImages == showImages) return;
    _showImages = showImages;
    [self updateShowImages];
}

- (void)updateShowImages
{
    [self evalJavaScript:@"Awful.showImages(%@)", JSONizeBool(self.showImages)];
}

- (void)setFontSize:(NSNumber *)size
{
    if ([_fontSize isEqual:size]) return;
    _fontSize = size;
    [self updateFontSize];
}

- (void)updateFontSize
{
    [self evalJavaScript:@"Awful.fontSize(%@)", self.fontSize];
}

- (void)setHighlightQuoteUsername:(NSString *)highlightQuoteUsername
{
    if (_highlightQuoteUsername == highlightQuoteUsername) return;
    _highlightQuoteUsername = [highlightQuoteUsername copy];
    [self updateHighlightQuoteUsername];
}

- (void)updateHighlightQuoteUsername
{
    [self evalJavaScript:@"Awful.highlightQuoteUsername(%@)",
     JSONizeValue(self.highlightQuoteUsername)];
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

- (NSInteger)indexOfPostWithActionButtonAtPoint:(CGPoint)point rect:(CGRect *)rect
{
    NSDictionary *postInfo = [self evalJavaScriptWithJSONResponse:
                              @"Awful.postWithButtonForPoint(%d, %d)", (int)point.x, (int)point.y];
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
    if (self.scrollView.contentOffset.y < 0) {
        rect.origin.y -= self.scrollView.contentOffset.y;
    }
    return rect;
}

- (NSURL *)URLOfSpoiledImageForPoint:(CGPoint)point
{
    NSDictionary *imageInfo = [self evalJavaScriptWithJSONResponse:
                               @"Awful.spoiledImageInPostForPoint(%d, %d)",
                               (int)point.x, (int)point.y];
    if ([imageInfo isKindOfClass:[NSDictionary class]]) {
        return [NSURL awful_URLWithString:imageInfo[@"url"]];
    } else {
        return nil;
    }
}

- (NSURL *)URLOfSpoiledLinkForPoint:(CGPoint)point rect:(CGRect *)rect
{
    NSDictionary *linkInfo = [self evalJavaScriptWithJSONResponse:
                              @"Awful.spoiledLinkInPostForPoint(%d, %d)",
                              (int)point.x, (int)point.y];
    if (![linkInfo isKindOfClass:[NSDictionary class]]) return nil;
    if (rect) {
        *rect = [self rectOfElementWithRectDictionary:linkInfo[@"rect"]];
    }
    return [NSURL awful_URLWithString:linkInfo[@"url"]];
}

- (NSURL *)URLOfSpoiledVideoForPoint:(CGPoint)point rect:(out CGRect *)rect
{
    NSDictionary *videoInfo = [self evalJavaScriptWithJSONResponse:
                               @"Awful.spoiledVideoInPostForPoint(%d, %d)",
                               (int)point.x, (int)point.y];
    if (![videoInfo isKindOfClass:[NSDictionary class]]) return nil;
    if (rect) {
        *rect = [self rectOfElementWithRectDictionary:videoInfo[@"rect"]];
    }
    return [NSURL awful_URLWithString:videoInfo[@"url"]];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    dispatch_once(&_onceOnFirstLoad, ^{
        [self updateDark];
        [self updateShowAvatars];
        [self updateShowImages];
        [self updateHighlightQuoteUsername];
        [self updateHighlightMentionUsername];
        [self updateEndMessage];
        [self updateFontSize];
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
       shouldReceiveTouch:(UITouch *)touch
{
    // iOS 5: allow buttons in subviews to receive touches.
    return ![touch.view isKindOfClass:[UIButton class]];
}

@end


NSURL * StylesheetURLForForumWithIDAndSettings(NSString * const forumID, AwfulSettings *settings)
{
    NSMutableArray *listOfFilenames = [@[ @"posts-view.css" ] mutableCopy];
    if (forumID) {
        NSString *specificCSS = [NSString stringWithFormat:@"posts-view-%@.css", forumID];
        if ([forumID isEqualToString:@"219"]) {
            AwfulYOSPOSStyle style = settings.yosposStyle;
            [listOfFilenames insertObject:specificCSS
                                  atIndex:style == AwfulYOSPOSStyleGreen ? 0 : 1];
            if (style == AwfulYOSPOSStyleAmber) {
                [listOfFilenames insertObject:@"posts-view-219-amber.css" atIndex:0];
            } else if (style == AwfulYOSPOSStyleMacinyos) {
                [listOfFilenames insertObject:@"posts-view-219-macinyos.css" atIndex:0];
            } else if (style == AwfulYOSPOSStyleWinpos95) {
                [listOfFilenames insertObject:@"posts-view-219-winpos95.css" atIndex:0];
            }
        } else if ([forumID isEqualToString:@"26"]) {
            if (settings.fyadStyle == AwfulFYADStylePink) {
                [listOfFilenames insertObject:specificCSS atIndex:0];
            }
        } else if ([forumID isEqualToString:@"25"]) {
            if (settings.gasChamberStyle == AwfulGasChamberStyleSickly) {
                [listOfFilenames insertObject:specificCSS atIndex:0];
            }
        } else {
            [listOfFilenames insertObject:specificCSS atIndex:0];
        }
    }
    NSURL *documents = [[NSFileManager defaultManager] documentDirectory];
    NSBundle *mainBundle = [NSBundle mainBundle];
    for (NSString *filename in listOfFilenames) {
        NSURL *url = [documents URLByAppendingPathComponent:filename];
        if ([url checkResourceIsReachableAndReturnError:nil]) return url;
        url = [mainBundle URLForResource:filename withExtension:nil];
        if ([url checkResourceIsReachableAndReturnError:nil]) return url;
    }
    return nil;
}
