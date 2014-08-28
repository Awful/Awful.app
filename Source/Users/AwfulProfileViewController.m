//  AwfulProfileViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulProfileViewController.h"
#import "AwfulActionSheet+WebViewSheets.h"
#import "BrowserViewController.h"
#import "AwfulExternalBrowser.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulModels.h"
#import "MessageComposeViewController.h"
#import "AwfulProfileViewModel.h"
#import "AwfulReadLaterService.h"
#import "AwfulSettings.h"
#import "AwfulWebViewNetworkActivityIndicatorManager.h"
#import <GRMustache.h>
#import <WebViewJavascriptBridge.h>
#import "Awful-Swift.h"

@interface AwfulProfileViewController ()

@property (readonly, strong, nonatomic) UIWebView *webView;

@property (strong, nonatomic) UIBarButtonItem *dismissButtonItem;

@end

@implementation AwfulProfileViewController
{
    AwfulWebViewNetworkActivityIndicatorManager *_networkActivityIndicatorManager;
    WebViewJavascriptBridge *_webViewJavaScriptBridge;
    NSDate *_mostRecentRefreshDate;
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
    self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
    
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
                [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
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
    AwfulActionSheet *sheet = [AwfulActionSheet actionSheetOpeningURL:homepage fromViewController:self addingActions:nil];
    sheet.title = homepage.absoluteString;
    [sheet showFromRect:rect inView:self.view animated:YES];
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
    _networkActivityIndicatorManager = [AwfulWebViewNetworkActivityIndicatorManager new];
    _webViewJavaScriptBridge = [WebViewJavascriptBridge bridgeForWebView:self.webView webViewDelegate:_networkActivityIndicatorManager handler:^(id data, WVJBResponseCallback _) {
        NSLog(@"%s %@", __PRETTY_FUNCTION__, data);
    }];
    __weak __typeof__(self) weakSelf = self;
    [_webViewJavaScriptBridge registerHandler:@"contactInfo" handler:^(NSDictionary *contactInfo, WVJBResponseCallback _) {
        __typeof__(self) self = weakSelf;
        NSString *service = contactInfo[@"service"];
        if ([service isEqualToString:@"Private Message"]) {
            MessageComposeViewController *messageViewController = [[MessageComposeViewController alloc] initWithRecipient:self.user];
            [self presentViewController:[messageViewController enclosingNavigationController] animated:YES completion:nil];
        } else if ([service isEqualToString:@"Homepage"]) {
            NSURL *URL = [NSURL URLWithString:contactInfo[@"address"] relativeToURL:[AwfulForumsClient client].baseURL];
            CGRect rect = [self.webView awful_rectForElementBoundingRect:contactInfo[@"rect"]];
            [self showActionsForHomepage:URL atRect:rect];
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
    [_webViewJavaScriptBridge callHandler:@"darkMode" data:@([AwfulSettings sharedSettings].darkTheme)];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.presentingViewController && self.navigationController.viewControllers.count == 1) {
        self.navigationItem.leftBarButtonItem = self.dismissButtonItem;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.webView.scrollView flashScrollIndicators];
    [self refreshIfNecessary];
}

@end
