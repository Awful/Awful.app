//  MessageViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "MessageViewController.h"
@import GRMustache;
@import WebViewJavascriptBridge;
#import "Awful-Swift.h"

@interface MessageViewController () <UIWebViewDelegate, ComposeTextViewControllerDelegate, UIGestureRecognizerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) PrivateMessage *privateMessage;

@property (readonly, strong, nonatomic) UIWebView *webView;

@property (strong, nonatomic) LoadingView *loadingView;

@property (strong, nonatomic) UIBarButtonItem *replyButtonItem;

@end

@implementation MessageViewController
{
    WebViewNetworkActivityIndicatorManager *_networkActivityIndicatorManager;
    WebViewJavascriptBridge *_webViewJavaScriptBridge;
    MessageComposeViewController *_composeViewController;
    BOOL _didRender;
    BOOL _didLoadOnce;
    CGFloat _fractionalContentOffsetOnLoad;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithPrivateMessage:(PrivateMessage *)privateMessage
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _privateMessage = privateMessage;
        self.title = privateMessage.subject;
        self.navigationItem.rightBarButtonItem = self.replyButtonItem;
        self.hidesBottomBarWhenPushed = YES;
        self.restorationClass = self.class;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(settingsDidChange:)
                                                     name:AwfulSettingsDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    NSAssert(nil, @"Use -initWithPrivateMessage: instead");
    return [self initWithPrivateMessage:nil];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSAssert(nil, @"Use -initWithPrivateMessage: instead");
    return [self initWithPrivateMessage:nil];
}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    self.navigationItem.titleLabel.text = title;
}

- (void)renderMessage
{
    PrivateMessageViewModel *viewModel = [[PrivateMessageViewModel alloc] initWithPrivateMessage:self.privateMessage];
    viewModel.stylesheet = self.theme[@"postsViewCSS"];
    NSError *error;
    NSString *HTML = [GRMustacheTemplate renderObject:viewModel fromResource:@"PrivateMessage" bundle:nil error:&error];
    if (!HTML) {
        NSLog(@"%s error rendering private message: %@", __PRETTY_FUNCTION__, error);
    }
    NSURL *baseURL = [AwfulForumsClient client].baseURL;
    [self.webView loadHTMLString:HTML baseURL:baseURL];
    _didRender = YES;
    self.webView.fractionalContentOffset = _fractionalContentOffsetOnLoad;
}

- (UIBarButtonItem *)replyButtonItem
{
    if (_replyButtonItem) return _replyButtonItem;
    _replyButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply
                                                                      target:self
                                                                      action:@selector(didTapReplyButtonItem:)];
    return _replyButtonItem;
}

- (void)didTapReplyButtonItem:(UIBarButtonItem *)buttonItem
{
    PrivateMessage *privateMessage = self.privateMessage;
    UIAlertController *actionSheet = [UIAlertController actionSheet];
    __weak __typeof__(self) weakSelf = self;
    
    [actionSheet addActionWithTitle:@"Reply" handler:^{
        [[AwfulForumsClient client] quoteBBcodeContentsOfPrivateMessage:privateMessage andThen:^(NSError *error, NSString *BBcode) {
            __typeof__(self) self = weakSelf;
            if (error) {
                [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Quote Message" error:error] animated:YES completion:nil];
            } else {
                _composeViewController = [[MessageComposeViewController alloc] initWithRegardingMessage:privateMessage
                                                                                        initialContents:BBcode];
                _composeViewController.delegate = self;
                _composeViewController.restorationIdentifier = @"New private message replying to private message";
                [self presentViewController:[_composeViewController enclosingNavigationController] animated:YES completion:nil];
            }
        }];
    }];
    
    [actionSheet addActionWithTitle:@"Forward" handler:^{
        [[AwfulForumsClient client] quoteBBcodeContentsOfPrivateMessage:self.privateMessage andThen:^(NSError *error, NSString *BBcode) {
            __typeof__(self) self = weakSelf;
            if (error) {
                [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Quote Message" error:error] animated:YES completion:nil];
            } else {
                _composeViewController = [[MessageComposeViewController alloc] initWithForwardingMessage:self.privateMessage
                                                                                         initialContents:BBcode];
                _composeViewController.delegate = self;
                _composeViewController.restorationIdentifier = @"New private message forwarding private message";
                [self presentViewController:[_composeViewController enclosingNavigationController] animated:YES completion:nil];
            }
        }];
    }];
    
    [actionSheet addCancelActionWithHandler:nil];
    [self presentViewController:actionSheet animated:YES completion:nil];
    actionSheet.popoverPresentationController.barButtonItem = buttonItem;
}

- (void)showUserActionsFromRect:(CGRect)rect
{
	InAppActionViewController *actionViewController = [InAppActionViewController new];
    NSMutableArray *items = [NSMutableArray new];
    User *user = self.privateMessage.from;
    
	[items addObject:[IconActionItem itemWithAction:IconActionUserProfile block:^{
        ProfileViewController *profile = [[ProfileViewController alloc] initWithUser:user];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
        } else {
            [self.navigationController pushViewController:profile animated:YES];
        }
	}]];
    
	[items addObject:[IconActionItem itemWithAction:IconActionRapSheet block:^{
        RapSheetViewController *rapSheet = [[RapSheetViewController alloc] initWithUser:user];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self presentViewController:[rapSheet enclosingNavigationController] animated:YES completion:nil];
        } else {
            [self.navigationController pushViewController:rapSheet animated:YES];
        }
	}]];
    
    actionViewController.items = items;
    actionViewController.popoverPositioningBlock = ^(CGRect *sourceRect, UIView * __autoreleasing *sourceView) {
        NSString *rectString = [self.webView stringByEvaluatingJavaScriptFromString:@"HeaderRect()"];
        *sourceRect = [self.webView rectForElementBoundingRect:rectString];
        *sourceView = self.webView;
    };
    [self presentViewController:actionViewController animated:YES completion:nil];
}

- (void)didLongPressWebView:(UILongPressGestureRecognizer *)sender
{
    if (sender.state == UIGestureRecognizerStateBegan) {
        CGPoint location = [sender locationInView:self.webView];
        CGFloat offsetY = self.webView.scrollView.contentOffset.y;
        if (offsetY < 0) {
            location.y += offsetY;
        }
        NSDictionary *data = @{ @"x": @(location.x), @"y": @(location.y) };
        __weak __typeof__(self) weakSelf = self;
        [_webViewJavaScriptBridge callHandler:@"interestingElementsAtPoint" data:data responseCallback:^(NSDictionary *response) {
            __typeof__(self) self = weakSelf;
            [self.webView stringByEvaluatingJavaScriptFromString:@"Awful.preventNextClickEvent()"];
            
            if (response.count == 0) return;
            
            BOOL ok = [URLMenuPresenter presentInterestingElements:response fromViewController:self fromWebView:self.webView];
            if (!ok && !response[@"unspoiledLink"]) {
                NSLog(@"%s unexpected interesting elements for data %@ response: %@", __PRETTY_FUNCTION__, data, response);
            }
        }];
    }
}

- (void)settingsDidChange:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    
    NSString *changedSetting = note.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([changedSetting isEqualToString:AwfulSettingsKeys.showAvatars]) {
        [_webViewJavaScriptBridge callHandler:@"showAvatars" data:@([AwfulSettings sharedSettings].showAvatars)];
    } else if ([changedSetting isEqualToString:AwfulSettingsKeys.showImages]) {
        if ([AwfulSettings sharedSettings].showImages) {
            [_webViewJavaScriptBridge callHandler:@"loadLinkifiedImages"];
        }
    } else if ([changedSetting isEqualToString:AwfulSettingsKeys.fontScale]) {
        [_webViewJavaScriptBridge callHandler:@"fontScale" data:@((int)[AwfulSettings sharedSettings].fontScale)];
    } else if ([changedSetting isEqualToString:AwfulSettingsKeys.handoffEnabled]) {
        if (self.visible) {
            [self configureUserActivity];
        }
    }
}

- (void)configureUserActivity
{
    if ([AwfulSettings sharedSettings].handoffEnabled) {
        self.userActivity = [[NSUserActivity alloc] initWithActivityType:Handoff.ActivityTypeReadingMessage];
        self.userActivity.needsSave = YES;
    }
}

- (void)updateUserActivityState:(NSUserActivity *)activity
{
    [activity addUserInfoEntriesFromDictionary:@{Handoff.InfoMessageIDKey: self.privateMessage.messageID}];
    NSString *subject = self.privateMessage.subject;
    activity.title = subject.length > 0 ? subject : @"Private Message";
    activity.webpageURL = [NSURL URLWithString:[NSString stringWithFormat:@"/private.php?action=show&privatemessageid=%@", self.privateMessage.messageID]
                                 relativeToURL:[AwfulForumsClient client].baseURL];
}

- (UIWebView *)webView
{
    return (UIWebView *)self.view;
}

- (void)loadView
{
    self.view = [UIWebView nativeFeelingWebView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _networkActivityIndicatorManager = [[WebViewNetworkActivityIndicatorManager alloc] initWithNextDelegate:self];
    _webViewJavaScriptBridge = [WebViewJavascriptBridge bridgeForWebView:self.webView webViewDelegate:_networkActivityIndicatorManager handler:^(id data, WVJBResponseCallback _) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, data);
    }];
    __weak __typeof__(self) weakSelf = self;
    [_webViewJavaScriptBridge registerHandler:@"didTapUserHeader" handler:^(NSString *rectString, WVJBResponseCallback responseCallback) {
        __typeof__(self) self = weakSelf;
        CGRect rect = [self.webView rectForElementBoundingRect:rectString];
        [self showUserActionsFromRect:rect];
    }];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressWebView:)];
    longPress.delegate = self;
    [self.webView addGestureRecognizer:longPress];
    
    if (self.privateMessage.innerHTML.length == 0 || self.privateMessage.from == nil) {
        self.loadingView = [LoadingView loadingViewWithTheme:self.theme];
        [self.view addSubview:self.loadingView];
        __weak __typeof__(self) weakSelf = self;
        [[AwfulForumsClient client] readPrivateMessageWithKey:self.privateMessage.objectKey andThen:^(NSError *error, PrivateMessage *message) {
            __typeof__(self) self = weakSelf;
            self.title = self.privateMessage.subject;
            [self renderMessage];
            [self.loadingView removeFromSuperview];
            self.loadingView = nil;
            self.userActivity.needsSave = YES;
            if (!message.seen) {
                [[NewMessageChecker sharedChecker] decrementUnreadCount];
                message.seen = YES;
            }
        }];
    } else {
        [self renderMessage];
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    Theme *theme = self.theme;
    if (_didRender) {
        [_webViewJavaScriptBridge callHandler:@"changeStylesheet" data:theme[@"postsViewCSS"]];
    }
    self.loadingView.tintColor = theme[@"backgroundColor"];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self configureUserActivity];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.userActivity = nil;
}

#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    NSURL *URL = request.URL;
    
    // Tapping the title of an embedded YouTube video doesn't come through as a click. It'll just take over the web view if we're not careful.
    if ([URL.host.lowercaseString hasSuffix:@"www.youtube.com"] && [URL.path.lowercaseString hasPrefix:@"/watch"]) {
        navigationType = UIWebViewNavigationTypeLinkClicked;
    }
    
    if (navigationType == UIWebViewNavigationTypeLinkClicked) {
        NSURL *awfulURL = URL.awfulURL;
        if (awfulURL) {
            [[AwfulAppDelegate instance] openAwfulURL:awfulURL];
        } else if ([URL opensInBrowser]) {
            [[[URLMenuPresenter alloc] initWithLinkURL:URL imageURL:nil] presentInDefaultBrowserFromViewController:self];
        } else {
            [[UIApplication sharedApplication] openURL:URL];
        }
        return NO;
    }
    
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!_didLoadOnce) {
        webView.fractionalContentOffset = _fractionalContentOffsetOnLoad;
        _didLoadOnce = YES;
    }
    
    if ([AwfulSettings sharedSettings].embedTweets) {
        [_webViewJavaScriptBridge callHandler:@"embedTweets"];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark - ComposeTextViewControllerDelegate

- (void)composeTextViewController:(ComposeTextViewController *)composeTextViewController
didFinishWithSuccessfulSubmission:(BOOL)success
                  shouldKeepDraft:(BOOL)keepDraft
{
    [self dismissViewControllerAnimated:YES completion:nil];
    _composeViewController = nil;
}

#pragma mark - State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    PrivateMessageKey *messageKey = [coder decodeObjectForKey:MessageKeyKey];
    if (!messageKey) {
        NSString *messageID = [coder decodeObjectForKey:obsolete_MessageIDKey];
        messageKey = [[PrivateMessageKey alloc] initWithMessageID:messageID];
    }
    NSManagedObjectContext *managedObjectContext = [AwfulAppDelegate instance].managedObjectContext;
    PrivateMessage *privateMessage = [PrivateMessage objectForKey:messageKey inManagedObjectContext:managedObjectContext];
    MessageViewController *messageViewController = [[self alloc] initWithPrivateMessage:privateMessage];
    messageViewController.restorationIdentifier = identifierComponents.lastObject;
    return messageViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.privateMessage.objectKey forKey:MessageKeyKey];
    [coder encodeObject:_composeViewController forKey:ComposeViewControllerKey];
    [coder encodeFloat:self.webView.fractionalContentOffset forKey:ScrollFractionKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    _composeViewController = [coder decodeObjectForKey:ComposeViewControllerKey];
    _composeViewController.delegate = self;
    _fractionalContentOffsetOnLoad = [coder decodeFloatForKey:ScrollFractionKey];
}

static NSString * const MessageKeyKey = @"MessageKey";
static NSString * const obsolete_MessageIDKey = @"AwfulMessageID";
static NSString * const ComposeViewControllerKey = @"AwfulComposeViewController";
static NSString * const ScrollFractionKey = @"AwfulScrollFraction";

@end
