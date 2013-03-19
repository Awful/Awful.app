//
//  ViewController.m
//  CSS Tweaker
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "ViewController.h"
#import "AwfulPostsView.h"

@interface AwfulPostsView (WebViewAccess)

@property (nonatomic) UIWebView *webView;

@end

@interface ViewController () <AwfulPostsViewDelegate>

@property (nonatomic) AwfulPostsView *postsView;
@property (nonatomic) NSArray *posts;

@end

@implementation ViewController

- (AwfulPostsView *)postsView
{
    return (id)self.view;
}

- (NSArray *)posts
{
    if (_posts) return _posts;
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"Posts" withExtension:@"plist"];
    _posts = [NSArray arrayWithContentsOfURL:url];
    return _posts;
}

- (void)toggleDarkMode
{
    self.postsView.dark = !self.postsView.dark;
}

- (void)loadStylesheetNamed:(NSString *)filename
{
    #if TARGET_IPHONE_SIMULATOR
        #include "LessFilesPath.h"
        filename = [NSString stringWithFormat:@"file://%@/%@", LessFilesPath, filename];
        [self.postsView.webView stringByEvaluatingJavaScriptFromString:@"$('style').remove()"];
    #endif
    self.postsView.stylesheetURL = [NSURL URLWithString:filename];
}

#pragma mark - UIViewController

- (void)loadView
{
    AwfulPostsView *postsView = [AwfulPostsView new];
    postsView.frame = [UIScreen mainScreen].applicationFrame;
    postsView.delegate = self;
    postsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    postsView.backgroundColor = [UIColor whiteColor];
    self.view = postsView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.postsView.showAvatars = YES;
    self.postsView.showImages = YES;
    #if TARGET_IPHONE_SIMULATOR
        [self startPollingForWhenWebViewLoads];
    #else
        self.postsView.stylesheetURL = [NSURL URLWithString:@"posts-view.css"];
    #endif
}

- (void)startPollingForWhenWebViewLoads
{
    [NSTimer scheduledTimerWithTimeInterval:.1 target:self selector:@selector(webViewLoadTick:)
                                   userInfo:nil repeats:YES];
}

- (void)webViewLoadTick:(NSTimer *)timer
{
    NSString *anything = [self.postsView.webView stringByEvaluatingJavaScriptFromString:@"$.os.ios"];
    if ([anything length] > 0) {
        [timer invalidate];
        [self webViewDidLoad];
    }
}

- (void)webViewDidLoad
{
    void (^eval)(id) = ^(NSString *js){
        [self.postsView.webView stringByEvaluatingJavaScriptFromString:js]; };
    #if TARGET_IPHONE_SIMULATOR
        #include "LessFilesPath.h"
        NSString *path = [@"file://" stringByAppendingString:LessFilesPath];
        path = [path stringByAppendingString:@"/posts-view.less"];
        self.postsView.stylesheetURL = [NSURL URLWithString:path];
        eval(@"$('link').attr('rel', 'stylesheet/less')");
        eval(@"window.location += '#!watch'");
        eval(@"var d=document,s=d.createElement('script');s.src='less.js';d.head.appendChild(s)");
    #endif
    eval(@"Awful.firstStylesheetDidLoad()");
}

#pragma mark - AwfulPostsViewDelegate

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView
{
    return [self.posts count];
}

- (NSDictionary *)postsView:(AwfulPostsView *)postsView postAtIndex:(NSInteger)index
{
    return self.posts[index];
}

@end
