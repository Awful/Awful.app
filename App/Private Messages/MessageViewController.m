//  MessageViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "MessageViewController.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulLoadingView.h"
#import "AwfulWebViewNetworkActivityIndicatorManager.h"
#import "PrivateMessageViewModel.h"
#import <WebViewJavascriptBridge/WebViewJavascriptBridge.h>
#import "Awful-Swift.h"

@interface MessageViewController () <UIWebViewDelegate, AwfulComposeTextViewControllerDelegate, UIGestureRecognizerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) PrivateMessage *privateMessage;

@property (readonly, strong, nonatomic) UIWebView *webView;

@property (strong, nonatomic) AwfulLoadingView *loadingView;

@property (strong, nonatomic) UIBarButtonItem *replyButtonItem;

@end

@implementation MessageViewController
{
    AwfulWebViewNetworkActivityIndicatorManager *_networkActivityIndicatorManager;
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
    self.webView.awful_fractionalContentOffset = _fractionalContentOffsetOnLoad;
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
    
	[items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeUserProfile action:^{
        ProfileViewController *profile = [[ProfileViewController alloc] initWithUser:user];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
        } else {
            [self.navigationController pushViewController:profile animated:YES];
        }
	}]];
    
	[items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeRapSheet action:^{
        RapSheetViewController *rapSheet = [[RapSheetViewController alloc] initWithUser:user];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self presentViewController:[rapSheet enclosingNavigationController] animated:YES completion:nil];
        } else {
            [self.navigationController pushViewController:rapSheet animated:YES];
        }
	}]];
    
    actionViewController.items = items;
    actionViewController.popoverPositioningBlock = ^(CGRect *sourceRect, UIView * __autoreleasing *sourceView) {
        NSString *rectString = [self.webView awful_evalJavaScript:@"HeaderRect()"];
        *sourceRect = [self.webView awful_rectForElementBoundingRect:rectString];
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
            if (response.count == 0) return;
            
            [self.webView awful_evalJavaScript:@"Awful.preventNextClickEvent()"];
            
            NSURL *imageURL = [NSURL URLWithString:response[@"spoiledImageURL"] relativeToURL:[AwfulForumsClient client].baseURL];
            if (response[@"spoiledLink"]) {
                NSDictionary *linkInfo = response[@"spoiledLink"];
                NSURL *URL = [NSURL URLWithString:linkInfo[@"URL"] relativeToURL:[AwfulForumsClient client].baseURL];
                CGRect rect = [self.webView awful_rectForElementBoundingRect:linkInfo[@"rect"]];
                [self showMenuForLinkToURL:URL fromRect:rect withImageURL:imageURL];
            } else if (imageURL) {
                [self previewImageAtURL:imageURL];
            } else if (response[@"spoiledVideo"]) {
                NSDictionary *videoInfo = response[@"spoiledVideo"];
                NSURL *URL = [NSURL URLWithString:videoInfo[@"URL"] relativeToURL:[AwfulForumsClient client].baseURL];
                CGRect rect = [self.webView awful_rectForElementBoundingRect:videoInfo[@"rect"]];
                [self showMenuForVideoAtURL:URL fromRect:rect];
            } else {
                if (response.count > 1 || !response[@"unspoiledLink"]) {
                    NSLog(@"%s unexpected interesting elements for data %@ response: %@", __PRETTY_FUNCTION__, data, response);
                }
            }
        }];
    }
}

- (void)showMenuForLinkToURL:(NSURL *)URL fromRect:(CGRect)rect withImageURL:(NSURL *)imageURL
{
    NSMutableArray *items = [NSMutableArray new];
    [items addObject:URL];
    NSMutableArray *activities = [NSMutableArray new];
    [activities addObject:[TUSafariActivity new]];
    [activities addObject:[ARChromeActivity new]];
    if (imageURL) {
        ImagePreviewActivity *imagePreview = [[ImagePreviewActivity alloc] initWithImageURL:imageURL];
        [items addObject:imagePreview];
        [activities addObject:imagePreview];
        [items addObject:[CopyURLActivity wrapURL:imageURL]];
        [activities addObject:[[CopyURLActivity alloc] initWithTitle:@"Copy Image URL"]];
    }
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:items applicationActivities:activities];
    [self presentViewController:activityViewController animated:YES completion:nil];
    UIPopoverPresentationController *popover = activityViewController.popoverPresentationController;
    popover.sourceRect = rect;
    popover.sourceView = self.view;
}

- (void)showMenuForVideoAtURL:(NSURL *)URL fromRect:(CGRect)rect
{
    NSURLComponents *components = [NSURLComponents new];
    if ([URL.host hasSuffix:@"youtube-nocookie.com"]) {
        components.scheme = @"http";
        components.host = @"www.youtube.com";
        components.path = @"/watch";
        components.query = [@"v=" stringByAppendingString:URL.lastPathComponent];
    } else if ([URL.host hasSuffix:@"player.vimeo.com"]) {
        components.scheme = @"http";
        components.host = @"vimeo.com";
        components.path = [@"/" stringByAppendingString:URL.lastPathComponent];
    } else {
        return;
    }
    
    UIAlertController *actionSheet = [UIAlertController actionSheet];
    
    [actionSheet addActionWithTitle:@"Open" handler:^{
        [YABrowserViewController presentBrowserForURL:components.URL fromViewController:self];
    }];
    
    NSString *openInTitle = @"Open in Safari";
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"youtube://"]]) {
        openInTitle = @"Open in YouTube";
    }
    [actionSheet addActionWithTitle:openInTitle handler:^{
        [[UIApplication sharedApplication] openURL:components.URL];
    }];
    
    [actionSheet addCancelActionWithHandler:nil];
    [self presentViewController:actionSheet animated:YES completion:nil];
    actionSheet.popoverPresentationController.sourceRect = rect;
    actionSheet.popoverPresentationController.sourceView = self.view;
}

- (void)previewImageAtURL:(NSURL *)URL
{
    ImageViewController *preview = [[ImageViewController alloc] initWithImageURL:URL];
    preview.title = self.title;
    [self presentViewController:preview animated:YES completion:nil];
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
    self.view = [UIWebView awful_nativeFeelingWebView];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _networkActivityIndicatorManager = [[AwfulWebViewNetworkActivityIndicatorManager alloc] initWithNextDelegate:self];
    _webViewJavaScriptBridge = [WebViewJavascriptBridge bridgeForWebView:self.webView webViewDelegate:_networkActivityIndicatorManager handler:^(id data, WVJBResponseCallback _) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, data);
    }];
    __weak __typeof__(self) weakSelf = self;
    [_webViewJavaScriptBridge registerHandler:@"didTapUserHeader" handler:^(NSString *rectString, WVJBResponseCallback responseCallback) {
        __typeof__(self) self = weakSelf;
        CGRect rect = [self.webView awful_rectForElementBoundingRect:rectString];
        [self showUserActionsFromRect:rect];
    }];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressWebView:)];
    longPress.delegate = self;
    [self.webView addGestureRecognizer:longPress];
    
    if (self.privateMessage.innerHTML.length == 0 || self.privateMessage.from == nil) {
        self.loadingView = [AwfulLoadingView loadingViewForTheme:self.theme];
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
            [YABrowserViewController presentBrowserForURL:URL fromViewController:self];
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
        webView.awful_fractionalContentOffset = _fractionalContentOffsetOnLoad;
        _didLoadOnce = YES;
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark - AwfulComposeTextViewControllerDelegate

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
    [coder encodeFloat:self.webView.awful_fractionalContentOffset forKey:ScrollFractionKey];
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
