//
//  AwfulProfileViewController.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulProfileViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulDateFormatters.h"
#import "AwfulExternalBrowser.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulPocketHelper.h"
#import "AwfulPostsView.h"
#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulSettings.h"
#import "NSManagedObject+Awful.h"
#import "NSURL+Punycode.h"
#import "SVProgressHUD.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulProfileViewController () <UIWebViewDelegate, AwfulPrivateMessageComposeViewControllerDelegate>

@property (readonly, nonatomic) UIWebView *webView;
@property (nonatomic) AwfulUser *user;
@property (copy, nonatomic) NSArray *services;

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

NSString * const AwfulServiceHomepage = @"Homepage";
NSString * const AwfulServicePrivateMessage = @"Private Message";

- (void)renderUser
{
    if (!self.user) return;
    self.title = self.user.username;
    NSDateFormatter *regdateFormatter = [AwfulDateFormatters formatters].regDateFormatter;
    NSDateFormatter *lastPostFormatter = [NSDateFormatter new];
    lastPostFormatter.locale = regdateFormatter.locale;
    lastPostFormatter.dateFormat = @"MMM d, yyyy HH:mm";
    NSMutableArray *contactInfo = [NSMutableArray new];
    if (self.user.canReceivePrivateMessagesValue && [AwfulSettings settings].canSendPrivateMessages) {
        [contactInfo addObject:@{
            @"service": AwfulServicePrivateMessage,
            @"address": self.user.username,
        }];
    }
    if ([self.user.aimName length] > 0) {
        [contactInfo addObject:@{ @"service": @"AIM", @"address": self.user.aimName }];
    }
    if ([self.user.icqName length] > 0) {
        [contactInfo addObject:@{ @"service": @"ICQ", @"address": self.user.icqName }];
    }
    if ([self.user.yahooName length] > 0) {
        [contactInfo addObject:@{ @"service": @"Yahoo!", @"address": self.user.yahooName }];
    }
    if ([self.user.homepageURL length] > 0) {
        [contactInfo addObject:@{
            @"service": AwfulServiceHomepage,
            @"address": self.user.homepageURL,
        }];
    }
    self.services = contactInfo;
    NSMutableArray *additionalInfo = [NSMutableArray new];
    if ([self.user.location length] > 0) {
        [additionalInfo addObject:@{ @"kind": @"Location", @"info": self.user.location }];
    }
    if ([self.user.interests length] > 0) {
        [additionalInfo addObject:@{ @"kind": @"Interests", @"info": self.user.interests }];
    }
    if ([self.user.occupation length] > 0) {
        [additionalInfo addObject:@{ @"kind": @"Occupation", @"info": self.user.occupation }];
    }
    NSString *postRate = @"";
    if (self.user.postRate) {
        postRate = [NSString stringWithFormat:@"%@ posts per day", self.user.postRate];
    }
    NSMutableDictionary *userDict = [@{
        @"customTitle": self.user.customTitle ?: [NSNull null],
        @"postCount": self.user.postCount ?: @0,
        @"username": self.user.username ?: @"",
        @"postRate": postRate,
        @"lastPost": [lastPostFormatter stringFromDate:self.user.lastPost] ?: [NSNull null],
        @"regdate": [regdateFormatter stringFromDate:self.user.regdate] ?: [NSNull null],
        @"gender": self.user.gender ?: @"porpoise",
        @"aboutMe": self.user.aboutMe ?: @"",
        @"anyContactInformation": @([contactInfo count] > 0),
        @"contactInformation": contactInfo,
        @"additionalInformation": additionalInfo,
        @"profilePictureURL": self.user.profilePictureURL ?: [NSNull null],
    } mutableCopy];
    if ([userDict[@"customTitle"] isEqual:@"<br/>"]) userDict[@"customTitle"] = [NSNull null];
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:userDict options:0 error:&error];
    if (!data) {
        NSLog(@"error serializing user dict %@: %@", userDict, error);
        return;
    }
    NSString *json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSString *js = [NSString stringWithFormat:@"Awful.render(%@)", json];
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
    self.view = webView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateDarkTheme];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsChanged:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
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

- (BOOL)webView:(UIWebView *)webView
shouldStartLoadWithRequest:(NSURLRequest *)request
 navigationType:(UIWebViewNavigationType)navigationType
{
    if ([request.URL.scheme isEqualToString:@"x-objc"]) {
        NSArray *whitelist = @[ @"showActionsForServiceAtIndex:fromRectDictionary:" ];
        InvokeBridgedMethodWithURLAndTarget(request.URL, self, whitelist);
        return NO;
    }
    return YES;
}

- (void)showActionsForServiceAtIndex:(NSNumber *)boxedi fromRectDictionary:(NSDictionary *)rectDict
{
    NSUInteger i = [boxedi unsignedIntegerValue];
    if (i >= [self.services count]) return;
    NSDictionary *service = self.services[i];
    CGRect rect = CGRectMake([rectDict[@"left"] floatValue], [rectDict[@"top"] floatValue],
                             [rectDict[@"width"] floatValue], [rectDict[@"height"] floatValue]);
    if ([service[@"service"] isEqual:AwfulServiceHomepage]) {
        NSURL *url = [NSURL awful_URLWithString:service[@"address"]];
        if (url) {
            [self showActionsForHomepage:url atRect:rect];
        }
    } else if ([service[@"service"] isEqual:AwfulServicePrivateMessage]) {
        AwfulPrivateMessageComposeViewController *compose;
        compose = [AwfulPrivateMessageComposeViewController new];
        compose.delegate = self;
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
    if ([AwfulPocketHelper isLoggedIn]) {
        [sheet addButtonWithTitle:@"Save to Pocket" block:^{
            [AwfulPocketHelper attemptToSaveURL:homepage];
        }];
    }
    [sheet addButtonWithTitle:@"Copy URL" block:^{
        [AwfulSettings settings].lastOfferedPasteboardURL = [homepage absoluteString];
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: homepage,
            (id)kUTTypePlainText: [homepage absoluteString],
        } ];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [sheet showFromRect:rect inView:self.view animated:YES];
    } else {
        [sheet showInView:self.view];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self updateDarkTheme];
    [self renderUser];
}

#pragma mark - AwfulPrivateMessageComposeViewControllerDelegate

- (void)privateMessageComposeControllerDidCancel:(AwfulPrivateMessageComposeViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)privateMessageComposeControllerDidSendMessage:(AwfulPrivateMessageComposeViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
