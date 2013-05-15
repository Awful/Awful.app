//
//  AwfulPostsView.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulPostsView.h"
#import "AwfulSettings.h"
#import "NSFileManager+UserDirectories.h"

@interface AwfulPostsView () <UIWebViewDelegate>

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
    _webView = webView;
    return self;
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

- (void)setLoadingMessage:(NSString *)loadingMessage
{
    if (_loadingMessage == loadingMessage) return;
    _loadingMessage = [loadingMessage copy];
    [self updateLoadingMessage];
}

- (void)updateLoadingMessage
{
    [self evalJavaScript:@"Awful.loading(%@)", JSONizeValue(self.loadingMessage)];
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
    [self evalJavaScript:@"Awful.endMessage(%@)", JSONizeValue(self.endMessage)];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    dispatch_once(&_onceOnFirstLoad, ^{
        [self updateDark];
        [self updateShowAvatars];
        [self updateShowImages];
        [self updateLoadingMessage];
        [self updateHighlightQuoteUsername];
        [self updateHighlightMentionUsername];
        [self updateEndMessage];
        [self updateFontSize];
        self.hasLoaded = YES;
        [self reloadData];
        self.webView.frame = (CGRect){ .size = self.bounds.size };
        [self addSubview:self.webView];
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
    if ([url.scheme isEqualToString:@"x-objc"]) {
        [self bridgeJavaScriptToObjectiveCWithURL:url];
        return NO;
    } else if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        if ([self.delegate respondsToSelector:@selector(postsView:didTapLinkToURL:)]) {
            [self.delegate postsView:self didTapLinkToURL:url];
        }
        return NO;
    } else if ([url.host hasSuffix:@"www.youtube.com"] && [url.path hasPrefix:@"/watch"]) {
        // Prevent YouTube embeds from taking over the whole frame. This would happen if you tap
        // the title of the video in the embed.
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

void InvokeBridgedMethodWithURLAndTarget(NSURL *url, id target, NSArray *whitelist)
{
    // Can't use [url pathComponents] because it can ignore multiple consecutive slashes.
    NSArray *components = [[url path] componentsSeparatedByString:@"/"];
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


const struct AwfulPostsViewKeys AwfulPostsViewKeys = {
    .innerHTML = @"innerHTML",
    .postID = @"postID",
    .postDate = @"postDate",
    .authorName = @"authorName",
    .authorAvatarURL = @"authorAvatarURL",
    .authorIsOriginalPoster = @"authorIsOriginalPoster",
    .authorIsAModerator = @"authorIsAModerator",
    .authorIsAnAdministrator = @"authorIsAnAdministrator",
    .authorRegDate = @"authorRegDate",
    .hasAttachment = @"hasAttachment",
    .editMessage = @"editMessage",
    .beenSeen = @"beenSeen",
};


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
    for (NSString *filename in listOfFilenames) {
        NSURL *url = [documents URLByAppendingPathComponent:filename];
        if ([url checkResourceIsReachableAndReturnError:NULL]) return url;
    }
    for (NSString *filename in listOfFilenames) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:filename
                                             withExtension:nil];
        if ([url checkResourceIsReachableAndReturnError:NULL]) return url;
    }
    return nil;
}
