//  AwfulPrivateMessageViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulBrowserViewController.h"
#import "AwfulDataStack.h"
#import "AwfulDateFormatters.h"
#import "AwfulExternalBrowser.h"
#import "AwfulHTTPClient.h"
#import "AwfulImagePreviewViewController.h"
#import "AwfulLoadingView.h"
#import "AwfulModels.h"
#import "AwfulPostsView.h"
#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulProfileViewController.h"
#import "AwfulReadLaterService.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThemingViewController.h"
#import <GRMustache/GRMustache.h>
#import "NSFileManager+UserDirectories.h"
#import "NSURL+Awful.h"
#import "NSURL+OpensInBrowser.h"
#import "NSURL+Punycode.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulPrivateMessageViewController () <AwfulPostsViewDelegate, AwfulThemingViewController,
                                                 AwfulPrivateMessageComposeViewControllerDelegate>

@property (nonatomic) AwfulPrivateMessage *privateMessage;
@property (readonly) AwfulPostsView *postsView;
@property (nonatomic) AwfulLoadingView *loadingView;

@end


@implementation AwfulPrivateMessageViewController

- (instancetype)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;;
    _privateMessage = privateMessage;
    self.title = privateMessage.subject;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    return self;
}

- (void)settingsDidChange:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    NSArray *relevant = @[ AwfulSettingsKeys.showAvatars,
                           AwfulSettingsKeys.showImages,
                           AwfulSettingsKeys.fontSize ];
    if ([note.userInfo[AwfulSettingsDidChangeSettingsKey] firstObjectCommonWithArray:relevant]) {
        [self configurePostsViewSettings];
    }
}

- (AwfulPostsView *)postsView
{
    return (id)self.view;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - AwfulThemingViewController

- (void)retheme
{
    self.view.backgroundColor = [AwfulTheme currentTheme].postsViewBackgroundColor;
    self.postsView.dark = [AwfulSettings settings].darkTheme;
    self.loadingView.tintColor = self.view.backgroundColor;
}

#pragma mark - UIViewController

- (void)loadView
{
    AwfulPostsView *view = [AwfulPostsView new];
    view.frame = [UIScreen mainScreen].applicationFrame;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    view.delegate = self;
    view.stylesheetURL = StylesheetURLForForumWithIDAndSettings(nil, nil);
    self.view = view;
    [self configurePostsViewSettings];
}

- (void)configurePostsViewSettings
{
    self.postsView.showAvatars = [AwfulSettings settings].showAvatars;
    self.postsView.showImages = [AwfulSettings settings].showImages;
    self.postsView.fontSize = [AwfulSettings settings].fontSize;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self retheme];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self.privateMessage.innerHTML length] == 0) {
        self.loadingView = [AwfulLoadingView loadingViewWithType:AwfulLoadingViewTypeDefault];
        self.loadingView.tintColor = [AwfulTheme currentTheme].postsViewBackgroundColor;
        self.loadingView.message = @"Loading…";
        [self.postsView addSubview:self.loadingView];
        [[AwfulHTTPClient client] readPrivateMessageWithID:self.privateMessage.messageID
                                                   andThen:^(NSError *error,
                                                             AwfulPrivateMessage *message)
         {
             [self.postsView reloadPostAtIndex:0];
             [self.loadingView removeFromSuperview];
             self.loadingView = nil;
         }];
    }
}

#pragma mark - AwfulPostsViewDelegate

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView
{
    return 1;
}

- (NSString *)postsView:(AwfulPostsView *)postsView renderedPostAtIndex:(NSInteger)index
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[AwfulPostAttributes.innerHTML] = self.privateMessage.innerHTML ?: @"";
    dict[@"beenSeen"] = self.privateMessage.seen ?: @NO;
    dict[AwfulPostAttributes.postDate] = self.privateMessage.sentDate ?: [NSNull null];
    dict[@"postDateFormat"] = AwfulDateFormatters.formatters.postDateFormatter;
    dict[AwfulPostRelationships.author] = self.privateMessage.from;
    dict[@"regDateFormat"] = AwfulDateFormatters.formatters.regDateFormatter;
    NSError *error;
    NSString *html = [GRMustacheTemplate renderObject:dict
                                         fromResource:@"Post"
                                               bundle:nil
                                                error:&error];
    if (!html) {
        NSLog(@"error rendering private message: %@", error);
    }
    return html;
}

- (void)postsView:(AwfulPostsView *)postsView didReceiveSingleTapAtPoint:(CGPoint)point
{
    CGRect rect;
    if ([postsView indexOfPostWithActionButtonAtPoint:point rect:&rect] != NSNotFound) {
        [self showPostActionsFromRect:rect];
    }
}

- (void)showPostActionsFromRect:(CGRect)rect
{
    rect = [self.postsView convertRect:rect toView:nil];
    NSString *title = [NSString stringWithFormat:@"%@'s Message",
                       self.privateMessage.from.username];
    AwfulActionSheet *sheet = [[AwfulActionSheet alloc] initWithTitle:title];
    [sheet addButtonWithTitle:@"Reply" block:^{
        [[AwfulHTTPClient client] quotePrivateMessageWithID:self.privateMessage.messageID
                                                    andThen:^(NSError *error, NSString *bbcode)
        {
            if (error) {
                [AwfulAlertView showWithTitle:@"Could Not Quote Message" error:error
                                  buttonTitle:@"OK"];
            } else {
                AwfulPrivateMessageComposeViewController *compose;
                compose = [AwfulPrivateMessageComposeViewController new];
                compose.delegate = self;
                [compose setRegardingMessage:self.privateMessage];
                [compose setMessageBody:bbcode];
                [self presentViewController:[compose enclosingNavigationController]
                                   animated:YES completion:nil];
            }
        }];
    }];
    [sheet addButtonWithTitle:@"Forward" block:^{
        [[AwfulHTTPClient client] quotePrivateMessageWithID:self.privateMessage.messageID
                                                    andThen:^(NSError *error, NSString *bbcode)
        {
            if (error) {
                [AwfulAlertView showWithTitle:@"Could Not Quote Message" error:error
                                  buttonTitle:@"OK"];
            } else {
                AwfulPrivateMessageComposeViewController *compose;
                compose = [AwfulPrivateMessageComposeViewController new];
                compose.delegate = self;
                [compose setForwardedMessage:self.privateMessage];
                [compose setMessageBody:bbcode];
                [self presentViewController:[compose enclosingNavigationController]
                                   animated:YES completion:nil];
            }
        }];
    }];
    [sheet addButtonWithTitle:@"User Profile" block:^{
        AwfulProfileViewController *profile = [AwfulProfileViewController new];
        profile.userID = self.privateMessage.from.userID;
        UIBarButtonItem *item;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                 target:self
                                                                 action:@selector(doneWithProfile)];
            profile.navigationItem.leftBarButtonItem = item;
            [self presentViewController:[profile enclosingNavigationController]
                               animated:YES completion:nil];
        } else {
            profile.hidesBottomBarWhenPushed = YES;
            [self.navigationController pushViewController:profile animated:YES];
        }
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromRect:rect inView:self.postsView.window animated:YES];
}

- (void)doneWithProfile
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)postsView:(AwfulPostsView *)postsView didReceiveLongTapAtPoint:(CGPoint)point
{
    NSURL *url;
    CGRect rect;
    if ((url = [postsView URLOfSpoiledImageForPoint:point])) {
        [self previewImageAtURL:url];
    } else if ((url = [postsView URLOfSpoiledLinkForPoint:point rect:&rect])) {
        [self showMenuForLinkToURL:url fromRect:rect];
    }
}

- (void)previewImageAtURL:(NSURL *)url
{
    AwfulImagePreviewViewController *preview = [[AwfulImagePreviewViewController alloc]
                                                initWithURL:url];
    preview.title = self.title;
    UINavigationController *nav = [preview enclosingNavigationController];
    nav.navigationBar.translucent = YES;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showMenuForLinkToURL:(NSURL *)url fromRect:(CGRect)rect
{
    if (![url opensInBrowser]) {
        [[UIApplication sharedApplication] openURL:url];
        return;
    }
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    sheet.title = url.absoluteString;
    [sheet addButtonWithTitle:@"Open" block:^{
        if ([url awfulURL]) {
            [[AwfulAppDelegate instance] openAwfulURL:[url awfulURL]];
        } else {
            [self openURLInBuiltInBrowser:url];
        }
    }];
    [sheet addButtonWithTitle:@"Open in Safari"
                        block:^{ [[UIApplication sharedApplication] openURL:url]; }];
    for (AwfulExternalBrowser *browser in [AwfulExternalBrowser installedBrowsers]) {
        if (![browser canOpenURL:url]) continue;
        [sheet addButtonWithTitle:[NSString stringWithFormat:@"Open in %@", browser.title]
                            block:^{ [browser openURL:url]; }];
    }
    for (AwfulReadLaterService *service in [AwfulReadLaterService availableServices]) {
        [sheet addButtonWithTitle:service.callToAction block:^{
            [service saveURL:url];
        }];
    }
    [sheet addButtonWithTitle:@"Copy URL" block:^{
        [UIPasteboard generalPasteboard].items = @[ @{
            (id)kUTTypeURL: url,
            (id)kUTTypePlainText: url.absoluteString
        }];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    rect = [self.postsView.superview convertRect:rect fromView:self.postsView];
    [sheet showFromRect:rect inView:self.postsView.superview animated:YES];
}

- (void)openURLInBuiltInBrowser:(NSURL *)url
{
    AwfulBrowserViewController *browser = [AwfulBrowserViewController new];
    browser.URL = url;
    browser.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:browser animated:YES];
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                             style:UIBarButtonItemStyleBordered
                                                            target:nil
                                                            action:NULL];
    self.navigationItem.backBarButtonItem = back;
}

- (void)postsView:(AwfulPostsView *)postsView willFollowLinkToURL:(NSURL *)url
{
    if ([url awfulURL]) {
        [[AwfulAppDelegate instance] openAwfulURL:[url awfulURL]];
    } else if ([url opensInBrowser]) {
        [self openURLInBuiltInBrowser:url];
    } else {
        [[UIApplication sharedApplication] openURL:url];
    }
}

#pragma mark - AwfulPrivateMessageComposeViewControllerDelegate

- (void)privateMessageComposeControllerDidSendMessage:(AwfulPrivateMessageComposeViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:^{
        [self.navigationController popViewControllerAnimated:YES]; 
    }];
}

- (void)privateMessageComposeControllerDidCancel:(AwfulPrivateMessageComposeViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
