//  AwfulProfileViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulProfileViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulDateFormatters.h"
#import "AwfulExternalBrowser.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulPostsView.h"
#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulProfileViewModel.h"
#import "AwfulReadLaterService.h"
#import "AwfulSettings.h"
#import <GRMustache/GRMustache.h>
#import "NSManagedObject+Awful.h"
#import "NSURL+Punycode.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulProfileViewController () <UIWebViewDelegate, UIGestureRecognizerDelegate>

@property (readonly, nonatomic) UIWebView *webView;
@property (nonatomic) AwfulUser *user;
@property (copy, nonatomic) NSArray *services;
@property (nonatomic) BOOL skipFetchingAndRenderingProfileOnAppear;

@end


@implementation AwfulProfileViewController

- (void)setUserID:(NSString *)userID
{
    if ([_userID isEqualToString:userID]) return;
    _userID = [userID copy];
    if (!_userID) {
        self.user = nil;
        return;
    }
    self.user = [AwfulUser firstMatchingPredicate:@"userID = %@", _userID];
}

- (void)renderUser
{
    if (!self.user) return;
    self.title = self.user.username;
    AwfulProfileViewModel *viewModel = [AwfulProfileViewModel newWithUser:self.user];
    self.services = viewModel.contactInfo;
    NSError *error;
    NSString *html = [GRMustacheTemplate renderObject:viewModel
                                         fromResource:@"Profile"
                                               bundle:nil
                                                error:&error];
    if (!html) {
        NSLog(@"error rendering profile for %@: %@", self.user.username, error);
        return;
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:@[ html ] options:0 error:&error];
    if (!data) {
        NSLog(@"error serializing profile json for %@: %@", self.user.username, error);
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

- (void)stopObserving
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AwfulSettingsDidChangeNotification
                                                  object:nil];
}

- (void)updateDarkTheme
{
    NSString *js = [NSString stringWithFormat:@"Awful.dark(%@)",
                    [AwfulSettings settings].darkTheme ? @"true" : @"false"];
    [self.webView stringByEvaluatingJavaScriptFromString:js];
}

- (void)settingsChanged:(NSNotification *)note
{
    NSArray *changed = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([changed containsObject:AwfulSettingsKeys.darkTheme]) [self updateDarkTheme];
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.title = @"Profile";
    self.modalPresentationStyle = UIModalPresentationFormSheet;
    return self;
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
        AwfulPrivateMessageComposeViewController *compose;
        compose = [AwfulPrivateMessageComposeViewController new];
        [compose setRecipient:self.user.username];
        
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
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self presentViewController:[compose enclosingNavigationController]
                               animated:YES completion:nil];
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

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateDarkTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsChanged:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    if (self.skipFetchingAndRenderingProfileOnAppear) return;
    [self renderUser];
    [[AwfulHTTPClient client] profileUserWithID:self.userID
                                        andThen:^(NSError *error, AwfulUser *user)
     {
         if (error) {
             NSLog(@"error fetching user profile for %@: %@", self.userID, error);
             if (!self.user) {
                 [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
             }
             return;
         }
         self.user = user;
         [self renderUser];
     }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.webView.scrollView flashScrollIndicators];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopObserving];
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) return YES;
    return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
}

- (void)dealloc
{
    if ([self isViewLoaded]) self.webView.delegate = nil;
    [self stopObserving];
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

@end
