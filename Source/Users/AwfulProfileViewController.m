//  AwfulProfileViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulProfileViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulDateFormatters.h"
#import "AwfulExternalBrowser.h"
#import "AwfulForumsClient.h"
#import "AwfulModels.h"
#import "AwfulNewPrivateMessageViewController.h"
#import "AwfulPostsView.h"
#import "AwfulProfileViewModel.h"
#import "AwfulReadLaterService.h"
#import "AwfulSettings.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <GRMustache/GRMustache.h>
#import <SVProgressHUD/SVProgressHUD.h>

@interface AwfulProfileViewController () <UIWebViewDelegate, UIGestureRecognizerDelegate, AwfulComposeTextViewControllerDelegate>

@property (readonly, strong, nonatomic) UIWebView *webView;

@property (copy, nonatomic) NSArray *services;

@property (assign, nonatomic) BOOL skipFetchingAndRenderingProfileOnAppear;

@end

@implementation AwfulProfileViewController

- (void)dealloc
{
    if ([self isViewLoaded]) {
        self.webView.delegate = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithUser:(AwfulUser *)user
{
    if (!(self = [super init])) return nil;
    _user = user;
    self.title = @"Profile";
    self.modalPresentationStyle = UIModalPresentationFormSheet;
    self.hidesBottomBarWhenPushed = YES;
    return self;
}

- (void)renderUser
{
    if (!self.user) return;
    self.title = self.user.username;
    AwfulProfileViewModel *viewModel = [AwfulProfileViewModel newWithUser:self.user];
    self.services = viewModel.contactInfo;
    NSError *error;
    NSString *html = [GRMustacheTemplate renderObject:viewModel fromResource:@"Profile" bundle:nil error:&error];
    if (!html) {
        NSLog(@"%s error rendering profile for %@: %@", __PRETTY_FUNCTION__, self.user.username, error);
        return;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[ html ] options:0 error:&error];
    if (!data) {
        NSLog(@"%s error serializing profile json for %@: %@", __PRETTY_FUNCTION__, self.user.username, error);
        return;
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *js = [NSString stringWithFormat:@"Awful.profile.render(%@[0])", json];
    [self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (UIWebView *)webView
{
    return (UIWebView *)self.view;
}

- (void)updateDarkTheme
{
    NSString *js = [NSString stringWithFormat:@"Awful.profile.dark(%@)", [AwfulSettings settings].darkTheme ? @"true" : @"false"];
    [self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)loadView
{
    UIWebView *webView = [[UIWebView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    webView.delegate = self;
    webView.scalesPageToFit = YES;
    webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    webView.dataDetectorTypes = UIDataDetectorTypeNone;
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"profile-view" withExtension:@"html"];
    NSError *error;
    NSString *html = [NSString stringWithContentsOfURL:url
                                              encoding:NSUTF8StringEncoding
                                                 error:&error];
    if (!html) {
        NSLog(@"error loading profile-view.html: %@", error);
        return;
    }
    [webView loadHTMLString:html baseURL:[[NSBundle mainBundle] resourceURL]];
    UITapGestureRecognizer *tap = [UITapGestureRecognizer new];
    tap.delegate = self;
    [tap addTarget:self action:@selector(didTap:)];
    [webView addGestureRecognizer:tap];
    self.view = webView;
}

- (void)didTap:(UITapGestureRecognizer *)tap
{
    CGPoint location = [tap locationInView:self.webView];
    NSString *js = [NSString stringWithFormat:@"Awful.profile.serviceFromPoint(%d, %d)",
                    (int)location.x, (int)location.y];
    NSString *json = [self.webView stringByEvaluatingJavaScriptFromString:js];
    NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
    // JSON errors are irrelevant here; the JavaScript function returns undefined if no service
    // was tapped.
    NSDictionary *tappedService = [NSJSONSerialization JSONObjectWithData:jsonData options:0
                                                                    error:nil];
    if (![tappedService isKindOfClass:[NSDictionary class]]) return;
    NSUInteger i = [tappedService[@"serviceIndex"] unsignedIntegerValue];
    if (i >= [self.services count]) return;
    self.skipFetchingAndRenderingProfileOnAppear = YES;
    NSDictionary *service = self.services[i];
    if ([service[@"service"] isEqual:AwfulServiceHomepage]) {
        NSURL *url = [NSURL awful_URLWithString:service[@"address"]];
        if (url) {
            NSDictionary *rectDict = tappedService[@"rect"];
            CGRect rect = CGRectMake([rectDict[@"left"] floatValue],
                                     [rectDict[@"top"] floatValue],
                                     [rectDict[@"width"] floatValue],
                                     [rectDict[@"height"] floatValue]);

            [self showActionsForHomepage:url atRect:rect];
        }
    } else if ([service[@"service"] isEqual:AwfulServicePrivateMessage]) {
        AwfulNewPrivateMessageViewController *newPrivateMessageViewController = [[AwfulNewPrivateMessageViewController alloc] initWithRecipient:self.user];
        newPrivateMessageViewController.delegate = self;
        
        // Try setting the delay to 0 then causing this to run. That is, as a user who can send PMs,
        // view the profile of a user who can receive PMs, and tap the "Private Message" row.
        //
        // On both iOS 5 and iOS 6, the keyboard is visible while presenting but immediately hides,
        // and the view is in an inconsistent state. The problem does not occur when presenting a
        // compose view from other screens such as the posts view or the PM list.
        //
        // In AwfulPrivateMessageComposeViewController, if you do not send -becomeFirstResponder
        // in response to entering the "Ready" state, then the problem goes away (but the keyboard
        // is not visible while or after presenting). If you send -becomeFirstResponder in an
        // implementation of -viewDidAppear: (as opposed to (indirectly) in -viewWillAppear:), the
        // problem again disappears (but the keyboard is not visible while presenting, and lamely
        // animates into view after presenting). Neither of these workarounds are desirable, as
        // they're only needed for presenting from this profile view.
        //
        // I cannot figure out why this happens, so that lamest of all Cocoa workarounds makes its
        // appearance here.
        //
        // TODO test this on iOS 7.
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^{
            [self presentViewController:[newPrivateMessageViewController enclosingNavigationController] animated:YES completion:nil];
        });
    } else {
        self.skipFetchingAndRenderingProfileOnAppear = NO;
    }
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self updateDarkTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
}

- (void)settingsDidChange:(NSNotification *)note
{
    if ([note.userInfo[AwfulSettingsDidChangeSettingKey] isEqual:AwfulSettingsKeys.darkTheme]) {
        [self updateDarkTheme];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (self.presentingViewController) {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                              target:self
                                                                                              action:@selector(dismiss)];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsChanged:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    if (self.skipFetchingAndRenderingProfileOnAppear) return;
    [self renderUser];
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] profileUserWithID:self.user.userID andThen:^(NSError *error, AwfulUser *user) {
        __typeof__(self) self = weakSelf;
         if (error) {
             NSLog(@"error fetching user profile for %@: %@", self.user.userID, error);
             if (!self.user) {
                 [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
             }
             return;
         }
        [self renderUser];
     }];
}

- (void)dismiss
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.webView.scrollView flashScrollIndicators];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.webView stopLoading];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self updateDarkTheme];
    [self renderUser];
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

#pragma mark - AwfulComposeTextViewControllerDelegate

- (void)composeTextViewController:(AwfulComposeTextViewController *)composeTextViewController
didFinishWithSuccessfulSubmission:(BOOL)success
                  shouldKeepDraft:(BOOL)keepDraft
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
