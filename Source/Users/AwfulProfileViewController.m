//  AwfulProfileViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulProfileViewController.h"
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulDateFormatters.h"
#import "AwfulExternalBrowser.h"
#import "AwfulForumsClient.h"
#import "AwfulModels.h"
#import "AwfulNewPrivateMessageViewController.h"
#import "AwfulProfileViewModel.h"
#import "AwfulReadLaterService.h"
#import "AwfulSettings.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <GRMustache.h>
#import <WebViewJavascriptBridge.h>

@interface AwfulProfileViewController () <UIWebViewDelegate>

@property (readonly, strong, nonatomic) UIWebView *webView;

@property (strong, nonatomic) UIBarButtonItem *dismissButtonItem;

@end

@implementation AwfulProfileViewController
{
    NSUInteger _webViewLoadingCount;
    WebViewJavascriptBridge *_webViewJavaScriptBridge;
    NSDate *_mostRecentRefreshDate;
}

- (void)dealloc
{
    if (_webViewLoadingCount > 0) {
        [[AFNetworkActivityIndicatorManager sharedManager] decrementActivityCount];
    }
}

- (id)initWithUser:(AwfulUser *)user
{
    self = [super init];
    if (!self) return nil;
    
    _user = user;
    NSString *username = user.username;
    self.title = username.length > 0 ? username : @"Profile";
    self.modalPresentationStyle = UIModalPresentationFormSheet;
    self.hidesBottomBarWhenPushed = YES;
    
    return self;
}

- (void)refreshIfNecessary
{
    if (([[NSDate date] timeIntervalSinceDate:_mostRecentRefreshDate] < 60 * 20)) return;
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] profileUserWithID:self.user.userID username:self.user.username andThen:^(NSError *error, AwfulUser *user) {
        __typeof__(self) self = weakSelf;
        if (error) {
            NSLog(@"error fetching user profile for %@: %@", self.user.userID, error);
            if (!self.user) {
                [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
            }
        } else {
            [self renderUser];
            _mostRecentRefreshDate = [NSDate date];
        }
    }];
}

- (void)renderUser
{
    AwfulProfileViewModel *viewModel = [[AwfulProfileViewModel alloc] initWithUser:self.user];
    NSError *error;
    NSString *HTML = [GRMustacheTemplate renderObject:viewModel fromResource:@"Profile" bundle:nil error:&error];
    if (!HTML) {
        NSLog(@"%s error rendering profile for %@: %@", __PRETTY_FUNCTION__, self.user.username, error);
    }
    [self.webView loadHTMLString:HTML baseURL:[AwfulForumsClient client].baseURL];
}

- (UIBarButtonItem *)dismissButtonItem
{
    if (_dismissButtonItem) return _dismissButtonItem;
    _dismissButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                       target:self
                                                                       action:@selector(dismiss)];
    return _dismissButtonItem;
}

- (void)dismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showActionsForHomepage:(NSURL *)homepage atRect:(CGRect)rect
{
    AwfulActionSheet *sheet = [[AwfulActionSheet alloc] initWithTitle:[homepage absoluteString]];
    [sheet addButtonWithTitle:@"Open in Safari" block:^{
        [[UIApplication sharedApplication] openURL:homepage];
    }];
    for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
        if (![browser canOpenURL:homepage]) continue;
        [sheet addButtonWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title]
                            block:^{ [browser openURL:homepage]; }];
    }
    for (AwfulReadLaterService *service in [AwfulReadLaterService availableServices]) {
        [sheet addButtonWithTitle:service.callToAction block:^{
            [service saveURL:homepage];
        }];
    }
    [sheet addButtonWithTitle:@"Copy URL" block:^{
        [AwfulSettings settings].lastOfferedPasteboardURL = [homepage absoluteString];
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: homepage,
            (id)kUTTypePlainText: [homepage absoluteString],
        }];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [sheet showFromRect:rect inView:self.view animated:YES];
    } else {
        [sheet showInView:self.view];
    }
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
    _webViewJavaScriptBridge = [WebViewJavascriptBridge bridgeForWebView:self.webView webViewDelegate:self handler:^(id data, WVJBResponseCallback _) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, data);
    }];
    __weak __typeof__(self) weakSelf = self;
    [_webViewJavaScriptBridge registerHandler:@"contactInfo" handler:^(NSDictionary *contactInfo, WVJBResponseCallback _) {
        __typeof__(self) self = weakSelf;
        NSString *service = contactInfo[@"service"];
        if ([service isEqualToString:@"Private Message"]) {
            AwfulNewPrivateMessageViewController *messageViewController = [[AwfulNewPrivateMessageViewController alloc] initWithRecipient:self.user];
            [self presentViewController:[messageViewController enclosingNavigationController] animated:YES completion:nil];
        } else if ([service isEqualToString:@"Homepage"]) {
            NSString *address = contactInfo[@"address"];
            NSDictionary *webViewRect = contactInfo[@"rect"];
            CGRect rect = CGRectMake([webViewRect[@"left"] floatValue], [webViewRect[@"top"] floatValue],
                                     [webViewRect[@"width"] floatValue], [webViewRect[@"height"] floatValue]);
            UIEdgeInsets insets = self.webView.scrollView.contentInset;
            rect = CGRectOffset(rect, insets.left, insets.top);
            [self showActionsForHomepage:[NSURL URLWithString:address] atRect:rect];
        }
    }];
    [self renderUser];
}

- (void)themeDidChange
{
    [super themeDidChange];
    AwfulTheme *theme = self.theme;
    self.view.backgroundColor = theme[@"backgroundColor"];
    self.webView.scrollView.indicatorStyle = theme.scrollIndicatorStyle;
    [self.webView awful_evalJavaScript:@"$('body').toggleClass('dark', %@)", [AwfulSettings settings].darkTheme ? @"true" : @"false"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.presentingViewController) {
        self.navigationItem.leftBarButtonItem = self.dismissButtonItem;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.webView.scrollView flashScrollIndicators];
    [self refreshIfNecessary];
}

#pragma mark UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    ++_webViewLoadingCount;
    if (_webViewLoadingCount == 1) {
        [[AFNetworkActivityIndicatorManager sharedManager] incrementActivityCount];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    --_webViewLoadingCount;
    if (_webViewLoadingCount == 0) {
        [[AFNetworkActivityIndicatorManager sharedManager] decrementActivityCount];
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    --_webViewLoadingCount;
    if (_webViewLoadingCount == 0) {
        [[AFNetworkActivityIndicatorManager sharedManager] decrementActivityCount];
    }
}

@end
