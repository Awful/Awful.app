//  MessageViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "MessageViewController.h"
#import <ARChromeActivity/ARChromeActivity.h>
#import "AwfulAppDelegate.h"
#import "AwfulDataStack.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulLoadingView.h"
#import "AwfulModels.h"
#import "AwfulPrivateMessageViewModel.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulWebViewNetworkActivityIndicatorManager.h"
#import "BrowserViewController.h"
#import <GRMustache/GRMustache.h>
#import "MessageComposeViewController.h"
#import "RapSheetViewController.h"
#import <TUSafariActivity/TUSafariActivity.h>
#import <WebViewJavascriptBridge.h>
#import "Awful-Swift.h"

@interface MessageViewController () <UIWebViewDelegate, AwfulComposeTextViewControllerDelegate, UIGestureRecognizerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) AwfulPrivateMessage *privateMessage;
@property (copy, nonatomic) NSString *messageID;
@property (strong, nonatomic) AwfulDataStack *dataStack;
@property (strong, nonatomic) WebViewJavascriptBridge *webViewJavaScriptBridge;
@property (strong, nonatomic) AwfulWebViewNetworkActivityIndicatorManager *networkActivityIndicatorManager;
@property (assign, nonatomic) BOOL didRender;
@property (assign, nonatomic) BOOL didLoadOnce;
@property (assign, nonatomic) CGFloat fractionalContentOffsetOnLoad;

@property (readonly, strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) AwfulLoadingView *loadingView;
@property (strong, nonatomic) UIBarButtonItem *replyButtonItem;
@property (strong, nonatomic) MessageComposeViewController *composeViewController;

@end

@implementation MessageViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _privateMessage = privateMessage;
        self.messageID = privateMessage.messageID;
        _dataStack = privateMessage.managedObjectContext.dataStack;
        
        self.title = privateMessage.subject;
        self.navigationItem.rightBarButtonItem = self.replyButtonItem;
        self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
        self.hidesBottomBarWhenPushed = YES;
        self.restorationClass = self.class;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(settingsDidChange:)
                                                     name:AwfulSettingsDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(dataStackWillReset:)
                                                     name:AwfulDataStackWillResetNotification
                                                   object:_dataStack];
    }
    return self;
}

- (AwfulPrivateMessage *)privateMessage
{
    if (!_privateMessage && self.dataStack && self.messageID.length > 0) {
        _privateMessage = [AwfulPrivateMessage firstOrNewPrivateMessageWithMessageID:self.messageID
                                                              inManagedObjectContext:self.dataStack.managedObjectContext];
    }
    return _privateMessage;
}

- (void)renderMessage
{
    AwfulPrivateMessageViewModel *viewModel = [[AwfulPrivateMessageViewModel alloc] initWithPrivateMessage:self.privateMessage];
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
    if (!_replyButtonItem) {
        _replyButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemReply target:nil action:nil];
        __weak __typeof__(self) weakSelf = self;
        _replyButtonItem.awful_actionBlock = ^(UIBarButtonItem *sender) {
          __typeof__(self) self = weakSelf;
            UIAlertController *actionSheet = [UIAlertController actionSheet];
            
            [actionSheet addActionWithTitle:@"Reply" handler:^{
                [[AwfulForumsClient client] quoteBBcodeContentsOfPrivateMessage:self.privateMessage andThen:^(NSError *error, NSString *BBcode) {
                    __typeof__(self) self = weakSelf;
                    if (error) {
                        [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Quote Message" error:error] animated:YES completion:nil];
                    } else {
                        self.composeViewController = [[MessageComposeViewController alloc] initWithRegardingMessage:self.privateMessage
                                                                                                initialContents:BBcode];
                        self.composeViewController.delegate = self;
                        self.composeViewController.restorationIdentifier = @"New private message replying to private message";
                        [self presentViewController:[self.composeViewController enclosingNavigationController] animated:YES completion:nil];
                    }
                }];
            }];
            
            [actionSheet addActionWithTitle:@"Forward" handler:^{
                [[AwfulForumsClient client] quoteBBcodeContentsOfPrivateMessage:self.privateMessage andThen:^(NSError *error, NSString *BBcode) {
                    __typeof__(self) self = weakSelf;
                    if (error) {
                        [self presentViewController:[UIAlertController alertWithTitle:@"Could Not Quote Message" error:error] animated:YES completion:nil];
                    } else {
                        self.composeViewController = [[MessageComposeViewController alloc] initWithForwardingMessage:self.privateMessage
                                                                                                 initialContents:BBcode];
                        self.composeViewController.delegate = self;
                        self.composeViewController.restorationIdentifier = @"New private message forwarding private message";
                        [self presentViewController:[self.composeViewController enclosingNavigationController] animated:YES completion:nil];
                    }
                }];
            }];
            
            [actionSheet addCancelActionWithHandler:nil];
            [self presentViewController:actionSheet animated:YES completion:nil];
            actionSheet.popoverPresentationController.barButtonItem = sender;
        };
    }
    return _replyButtonItem;
}

- (void)showUserActionsFromRect:(CGRect)rect
{
	InAppActionViewController *actionViewController = [InAppActionViewController new];
    NSMutableArray *items = [NSMutableArray new];
    AwfulUser *user = self.privateMessage.from;
    
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
        [items addObject:imageURL];
        [activities addObject:[ImagePreviewActivity new]];
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
        [BrowserViewController presentBrowserForURL:components.URL fromViewController:self];
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
    ImageViewController *preview = [[ImageViewController alloc] initWithURL:URL];
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
    }
}

- (void)dataStackWillReset:(NSNotification *)notification
{
    _privateMessage = nil;
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
    self.networkActivityIndicatorManager = [[AwfulWebViewNetworkActivityIndicatorManager alloc] initWithNextDelegate:self];
    self.webViewJavaScriptBridge = [WebViewJavascriptBridge bridgeForWebView:self.webView webViewDelegate:_networkActivityIndicatorManager handler:^(id data, WVJBResponseCallback _) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, data);
    }];
    __weak __typeof__(self) weakSelf = self;
    [self.webViewJavaScriptBridge registerHandler:@"didTapUserHeader" handler:^(NSString *rectString, WVJBResponseCallback responseCallback) {
        __typeof__(self) self = weakSelf;
        CGRect rect = [self.webView awful_rectForElementBoundingRect:rectString];
        [self showUserActionsFromRect:rect];
    }];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPressWebView:)];
    longPress.delegate = self;
    [self.webView addGestureRecognizer:longPress];
    
    if (self.privateMessage.innerHTML.length == 0) {
        self.loadingView = [AwfulLoadingView loadingViewForTheme:self.theme];
        self.loadingView.message = @"Loading…";
        [self.view addSubview:self.loadingView];
        [[AwfulForumsClient client] readPrivateMessage:self.privateMessage andThen:^(NSError *error) {
            __typeof__(self) self = weakSelf;
            self.title = self.privateMessage.subject;
            [self renderMessage];
            [self.loadingView removeFromSuperview];
            self.loadingView = nil;
        }];
    } else {
        [self renderMessage];
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    AwfulTheme *theme = self.theme;
    if (self.didRender) {
        [self.webViewJavaScriptBridge callHandler:@"changeStylesheet" data:theme[@"postsViewCSS"]];
    }
    self.view.backgroundColor = theme[@"backgroundColor"];
    self.webView.scrollView.indicatorStyle = theme.scrollIndicatorStyle;
    self.loadingView.tintColor = theme[@"backgroundColor"];
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
            [BrowserViewController presentBrowserForURL:URL fromViewController:self];
        } else {
            [[UIApplication sharedApplication] openURL:URL];
        }
        return NO;
    }
    
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    if (!self.didLoadOnce) {
        webView.awful_fractionalContentOffset = self.fractionalContentOffsetOnLoad;
        self.didLoadOnce = YES;
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
    NSManagedObjectContext *managedObjectContext = [AwfulAppDelegate instance].dataStack.managedObjectContext;
    NSString *messageID = [coder decodeObjectForKey:MessageIDKey];
    AwfulPrivateMessage *privateMessage = [AwfulPrivateMessage fetchArbitraryInManagedObjectContext:managedObjectContext
                                                                            matchingPredicateFormat:@"messageID = %@", messageID];
    MessageViewController *messageViewController = [[self alloc] initWithPrivateMessage:privateMessage];
    messageViewController.restorationIdentifier = identifierComponents.lastObject;
    NSError *error;
    if (![managedObjectContext save:&error]) {
        NSLog(@"%s error saving managed object context: %@", __PRETTY_FUNCTION__, error);
    }
    return messageViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.privateMessage.messageID forKey:MessageIDKey];
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

static NSString * const MessageIDKey = @"AwfulMessageID";
static NSString * const ComposeViewControllerKey = @"AwfulComposeViewController";
static NSString * const ScrollFractionKey = @"AwfulScrollFraction";

@end
