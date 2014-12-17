// YABrowserViewController.m  https://github.com/nolanw/YABrowserViewController  Public Domain

#import "YABrowserViewController.h"

@interface YABrowserViewController () <UITableViewDataSource, UITableViewDelegate>

@property (readonly, nonatomic) NSBundle *resourceBundle;

// Button items that always appear.
@property (strong, nonatomic) UIBarButtonItem *backButton;
@property (strong, nonatomic) UIBarButtonItem *forwardButton;
@property (strong, nonatomic) UIBarButtonItem *shareButton;
@property (strong, nonatomic) UIBarButtonItem *stopButton;
@property (strong, nonatomic) UIBarButtonItem *refreshButton;

@property (strong, nonatomic) UIProgressView *progressView;

// Only appears when presented modally via -presentFromViewController:animated:completion:.
@property (strong, nonatomic) UIBarButtonItem *closeButton;

@property (strong, nonatomic) UILongPressGestureRecognizer *longPressBack;

@property (assign, nonatomic) BOOL toolbarWasHidden;

@end

@implementation YABrowserViewController

@synthesize URLString = _URLString;

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        CommonInit(self);
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        CommonInit(self);
    }
    return self;
}

static void CommonInit(YABrowserViewController *self)
{
    [self reloadTitle];
    [self reloadBarButtonItems];
    self.restorationClass = [YABrowserViewController class];
    self.navigationItem.leftItemsSupplementBackButton = YES;
}

- (void)dealloc
{
    if ([self isViewLoaded]) {
        [self.webView removeObserver:self forKeyPath:@"title" context:KVOContext];
        [self.webView removeObserver:self forKeyPath:@"URL" context:KVOContext];
        [self.webView removeObserver:self forKeyPath:@"loading" context:KVOContext];
        [self.webView removeObserver:self forKeyPath:@"estimatedProgress" context:KVOContext];
    }
}

- (NSString *)URLString
{
    if ([self isViewLoaded]) {
        return self.webView.URL.absoluteString ?: _URLString;
    }
    return _URLString;
}

- (void)setURLString:(NSString *)URLString
{
    if ([self isViewLoaded]) {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:URLString]];
        [self.webView loadRequest:request];
    } else {
        _URLString = URLString;
    }
}

- (void)presentFromViewController:(UIViewController *)presentingViewController animated:(BOOL)animated completion:(void (^)(void))completion
{
    self.closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(didTapDone)];
    self.closeButton.accessibilityLabel = NSLocalizedStringFromTable(@"Close", @"YABrowserViewController", @"Modal presentation close button accessibility label");
    [self reloadBarButtonItems];
    
    UINavigationController *navigation = self.navigationController ?: [[UINavigationController alloc] initWithRootViewController:self];
    navigation.hidesBarsOnSwipe = YES;
    [presentingViewController presentViewController:navigation animated:animated completion:completion];
}

- (NSBundle *)resourceBundle
{
    NSBundle *thisBundle = [NSBundle bundleForClass:[YABrowserViewController class]];
    NSURL *podResourceURL = [thisBundle URLForResource:@"YABrowserViewController" withExtension:@"bundle"];
    if (podResourceURL) {
        return [NSBundle bundleWithURL:podResourceURL];
    }
    return thisBundle;
}

- (void)reloadTitle
{
    if ([self isViewLoaded] && self.webView.title.length > 0) {
        self.title = self.webView.title;
    } else if (self.URLString.length > 0) {
        self.title = self.URLString;
    }
    
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    NSDictionary *barTextAttributes = navigationBar.titleTextAttributes;
    UIColor *textColor = barTextAttributes[NSForegroundColorAttributeName];
    if (!textColor) {
        textColor = navigationBar.barStyle == UIBarStyleBlack ? [UIColor whiteColor] : [UIColor blackColor];
    }
    
    NSMutableAttributedString *titleString = [NSMutableAttributedString new];
    
    if ([self isViewLoaded] && self.webView.title.length > 0) {
        UIFont *titleFont = barTextAttributes[NSFontAttributeName] ?: [UIFont boldSystemFontOfSize:12];
        NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
        [titleString appendAttributedString:[[NSAttributedString alloc] initWithString:self.webView.title
                                                                            attributes:@{NSFontAttributeName: titleFont,
                                                                                         NSForegroundColorAttributeName: textColor,
                                                                                         NSParagraphStyleAttributeName: paragraphStyle}]];
    }
    
    if (self.URLString.length > 0) {
        [titleString.mutableString appendString:@"\n"];
        
        UIFont *URLFont;
        if (barTextAttributes[NSFontAttributeName]) {
            UIFont *titleFont = barTextAttributes[NSFontAttributeName];
            URLFont = [UIFont fontWithName:titleFont.fontName size:titleFont.pointSize - 2];
        } else {
            URLFont = [UIFont systemFontOfSize:10];
        }
        NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
        paragraphStyle.alignment = NSTextAlignmentCenter;
        paragraphStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
        [titleString appendAttributedString:[[NSAttributedString alloc] initWithString:self.URLString
                                                                            attributes:@{NSFontAttributeName: URLFont,
                                                                                         NSForegroundColorAttributeName: textColor,
                                                                                         NSParagraphStyleAttributeName: paragraphStyle}]];
    }
    
    if (!self.navigationItem.titleView || [self.navigationItem.titleView isKindOfClass:[UILabel class]]) {
        UILabel *label = [UILabel new];
        label.numberOfLines = 2;
        self.navigationItem.titleView = label;
    }
    
    UILabel *label = (UILabel *)self.navigationItem.titleView;
    label.attributedText = titleString;
    [label sizeToFit];
}

- (UIBarButtonItem *)backButton
{
    if (!_backButton) {
        NSBundle *bundle = [self resourceBundle];
        _backButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back" inBundle:bundle compatibleWithTraitCollection:nil]
                                         landscapeImagePhone:[UIImage imageNamed:@"back-landscape" inBundle:bundle compatibleWithTraitCollection:nil]
                                                       style:UIBarButtonItemStylePlain
                                                      target:self
                                                      action:@selector(goBack)];
        _backButton.accessibilityLabel = NSLocalizedStringFromTable(@"Back", @"YABrowserViewController", @"Back button accessibility label");
    }
    return _backButton;
}

- (void)goBack
{
    [self.webView goBack];
}

- (UILongPressGestureRecognizer *)longPressBack
{
    if (!_longPressBack) {
        _longPressBack = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressBackButton:)];
    }
    return _longPressBack;
}

- (void)didLongPressBackButton:(UILongPressGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        UITableViewController *historyViewController = [UITableViewController new];
        historyViewController.title = NSLocalizedStringFromTable(@"History", @"YABrowserViewController", @"History screen title");
        historyViewController.tableView.dataSource = self;
        historyViewController.tableView.delegate = self;
        historyViewController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(didTapDone)];
        
        if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            historyViewController.modalPresentationStyle = UIModalPresentationPopover;
            historyViewController.popoverPresentationController.barButtonItem = self.backButton;
            [self presentViewController:historyViewController animated:YES completion:nil];
        } else {
            UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:historyViewController];
            [self presentViewController:navigation animated:YES completion:nil];
        }
    }
}

- (void)didTapDone
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (UIBarButtonItem *)forwardButton
{
    if (!_forwardButton) {
        NSBundle *bundle = [self resourceBundle];
        _forwardButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"forward" inBundle:bundle compatibleWithTraitCollection:nil]
                                            landscapeImagePhone:[UIImage imageNamed:@"forward-landscape" inBundle:bundle compatibleWithTraitCollection:nil]
                                                          style:UIBarButtonItemStylePlain
                                                         target:self
                                                         action:@selector(goForward)];
        _forwardButton.accessibilityLabel = NSLocalizedStringFromTable(@"Forward", @"YABrowserViewController", @"Forward button accessibility label");
    }
    return _forwardButton;
}

- (void)goForward
{
    [self.webView goForward];
}

- (UIBarButtonItem *)shareButton
{
    if (!_shareButton) {
        _shareButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(didTapShareButtonItem:)];
    }
    return _shareButton;
}

- (void)didTapShareButtonItem:(UIBarButtonItem *)sender
{
    NSMutableArray *activityItems = [NSMutableArray new];
    if (self.webView.title.length > 0) {
        [activityItems addObject:self.webView.title];
    }
    if (self.webView.URL) {
        [activityItems addObject:self.webView.URL];
    }
    
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:self.applicationActivities];
    activityViewController.popoverPresentationController.barButtonItem = sender;
    [self presentViewController:activityViewController animated:YES completion:nil];
}

- (UIBarButtonItem *)stopButton
{
    if (!_stopButton) {
        _stopButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stopLoading)];
    }
    return _stopButton;
}

- (void)stopLoading
{
    [self.webView stopLoading];
}

- (UIBarButtonItem *)refreshButton
{
    if (!_refreshButton) {
        _refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadFromOrigin)];
    }
    return _refreshButton;
}

- (void)reloadFromOrigin
{
    [self.webView reloadFromOrigin];
}

- (void)reloadBarButtonItems
{
    // Order is important here: add the items to their bar first, otherwise the gesture recognizer doesn't stick to the view.
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        NSMutableArray *leftItems = [NSMutableArray new];
        if (self.closeButton) {
            [leftItems addObject:self.closeButton];
        }
        [leftItems addObjectsFromArray:@[self.backButton, self.forwardButton]];
        self.navigationItem.leftBarButtonItems = leftItems;
        
        NSMutableArray *rightItems = [NSMutableArray new];
        [rightItems addObject:self.shareButton];
        if ([self isViewLoaded] && self.webView.loading) {
            [rightItems addObject:self.stopButton];
        } else {
            [rightItems addObject:self.refreshButton];
        }
        self.navigationItem.rightBarButtonItems = rightItems;
    } else {
        if (self.closeButton) {
            self.navigationItem.leftBarButtonItem = self.closeButton;
        }
        
        NSMutableArray *toolbarItems = [NSMutableArray new];
        UIBarButtonItem * (^flexibleItem)() = ^{ return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]; };
        [toolbarItems addObjectsFromArray:@[self.backButton, flexibleItem(), self.forwardButton, flexibleItem(), self.shareButton, flexibleItem()]];
        if ([self isViewLoaded] && self.webView.loading) {
            [toolbarItems addObject:self.stopButton];
        } else {
            [toolbarItems addObject:self.refreshButton];
        }
        self.toolbarItems = toolbarItems;
    }
    
    self.backButton.enabled = [self isViewLoaded] ? self.webView.canGoBack : YES;
    self.backButton.accessibilityHint = self.backButton.enabled ? NSLocalizedStringFromTable(@"Double-tap and hold to show history", @"YABrowserViewController", @"Back button accessibility hint") : nil;
    self.longPressBack.enabled = self.backButton.enabled;
    // HACK: A bar button item's (non-custom) view is private API.
    [[self.backButton valueForKey:@"view"] addGestureRecognizer:self.longPressBack];
    
    self.forwardButton.enabled = [self isViewLoaded] ? self.webView.canGoForward : YES;
}

- (UIProgressView *)progressView
{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    }
    return _progressView;
}

- (void)presentError:(NSError *)error
{
    if ([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled) {
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Network Error" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedStringFromTable(@"OK", @"YABrowserViewController", @"OK button for error alert") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == KVOContext) {
        if ([keyPath isEqualToString:@"title"]) {
            [self reloadTitle];
        } else if ([keyPath isEqualToString:@"URL"]) {
            [self reloadTitle];
            _URLString = nil;
        } else if ([keyPath isEqualToString:@"loading"]) {
            [self reloadBarButtonItems];
        } else if ([keyPath isEqualToString:@"estimatedProgress"]) {
            self.progressView.alpha = 1;
            BOOL animated = self.progressView.progress < self.webView.estimatedProgress;
            [self.progressView setProgress:self.webView.estimatedProgress animated:animated];
            
            if (self.webView.estimatedProgress >= 1) {
                [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:0 animations:^{
                    self.progressView.alpha = 0;
                } completion:^(BOOL finished) {
                    self.progressView.progress = 0;
                }];
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

static void * KVOContext = &KVOContext;

- (WKWebView *)webView
{
    return (WKWebView *)self.view;
}

- (void)loadView
{
    WKWebView *webView = [WKWebView new];
    webView.backgroundColor = [UIColor whiteColor];
    webView.allowsBackForwardNavigationGestures = YES;
    webView.navigationDelegate = self;
    webView.UIDelegate = self;
    self.view = webView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.webView addObserver:self forKeyPath:@"title" options:0 context:KVOContext];
    [self.webView addObserver:self forKeyPath:@"URL" options:0 context:KVOContext];
    [self.webView addObserver:self forKeyPath:@"loading" options:0 context:KVOContext];
    [self.webView addObserver:self forKeyPath:@"estimatedProgress" options:0 context:KVOContext];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (_URLString.length > 0) {
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:_URLString]];
        [self.webView loadRequest:request];
    }
    
    self.toolbarWasHidden = self.navigationController.toolbarHidden;
    [self.navigationController setToolbarHidden:(self.toolbarItems.count == 0) animated:YES];
    [self.navigationController.navigationBar addSubview:self.progressView];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    UINavigationBar *navigationBar = self.navigationController.navigationBar;
    CGRect frame = self.progressView.frame;
    frame.origin = CGPointMake(0, CGRectGetMaxY(navigationBar.bounds) - CGRectGetHeight(frame));
    frame.size.width = CGRectGetWidth(navigationBar.bounds);
    self.progressView.frame = frame;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.navigationController.toolbarHidden = self.toolbarWasHidden;
    [self.progressView removeFromSuperview];
}

// If the navigation controller hides bars on swipe, these two overrides make that work nicely.

- (BOOL)prefersStatusBarHidden
{
    return self.navigationController.navigationBarHidden;
}

- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation
{
    return UIStatusBarAnimationSlide;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
    // Handle tapped links to non-http(s) URL schemes, as WKWebView will just silently cancel. https://github.com/ShingoFukuyama/WKWebViewTips
    if (navigationAction.navigationType == WKNavigationTypeLinkActivated) {
        NSURL *URL = navigationAction.request.URL;
        if (!([URL.scheme caseInsensitiveCompare:@"http"] == NSOrderedSame || [URL.scheme caseInsensitiveCompare:@"https"] == NSOrderedSame)) {
            
            // tel: will immediately start a phone call. That's rather impolite; let's ask first.
            if ([URL.scheme caseInsensitiveCompare:@"tel"] == NSOrderedSame) {
                NSURLComponents *components = [NSURLComponents componentsWithURL:URL resolvingAgainstBaseURL:YES];
                components.scheme = @"telprompt";
                URL = components.URL;
            }
            
            if ([[UIApplication sharedApplication] canOpenURL:URL]) {
                [[UIApplication sharedApplication] openURL:URL];
                decisionHandler(WKNavigationActionPolicyCancel);
                return;
            }
        } else if ([URL.host.lowercaseString isEqualToString:@"itunes.apple.com"]) {
            [[UIApplication sharedApplication] openURL:URL];
            decisionHandler(WKNavigationActionPolicyCancel);
            return;
        }
    }
    
    decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation
{
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self presentError:error];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    [self presentError:error];
}

#pragma mark - WKUIDelegate

- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures
{
    // Handle links that have target=_blank. http://stackoverflow.com/a/25853806/1063051
    if (!navigationAction.targetFrame.isMainFrame) {
        [webView loadRequest:navigationAction.request];
    }
    
    return nil;
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.webView.backForwardList.backList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const identifier = @"History cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    }
    WKBackForwardListItem *historyItem = self.webView.backForwardList.backList[indexPath.row];
    
    cell.textLabel.text = historyItem.title;
    cell.detailTextLabel.text = historyItem.URL.absoluteString;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    WKBackForwardListItem *historyItem = self.webView.backForwardList.backList[indexPath.row];
    [self.webView goToBackForwardListItem:historyItem];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIViewControllerRestoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    YABrowserViewController *viewController = [self new];
    viewController.restorationIdentifier = identifierComponents.lastObject;
    return viewController;
}

#pragma mark - UIStateRestoring (but not officially)

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    
    [coder encodeObject:self.title forKey:TitleKey];
    [coder encodeObject:self.URLString forKey:URLStringKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    
    self.title = [coder decodeObjectForKey:TitleKey];
    self.URLString = [coder decodeObjectForKey:URLStringKey];
}

static NSString * const TitleKey = @"title";
static NSString * const URLStringKey = @"URLString";

@end
