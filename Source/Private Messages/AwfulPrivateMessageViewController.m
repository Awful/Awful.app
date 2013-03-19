//
//  AwfulPrivateMessageViewController.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulPrivateMessageViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulDataStack.h"
#import "AwfulDateFormatters.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulPostsView.h"
#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThemingViewController.h"
#import "NSFileManager+UserDirectories.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulPrivateMessageViewController () <AwfulPostsViewDelegate, AwfulThemingViewController,
                                                 AwfulPrivateMessageComposeViewControllerDelegate>

@property (nonatomic) AwfulPrivateMessage *privateMessage;

@property (readonly) AwfulPostsView *postsView;

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
    [self configurePostsViewSettings];
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
    self.postsView.showImages = [AwfulSettings settings].showImages;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self retheme];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[AwfulHTTPClient client] readPrivateMessageWithID:self.privateMessage.messageID
                                               andThen:^(NSError *error,
                                                         AwfulPrivateMessage *message)
    {
        [self.postsView reloadPostAtIndex:0];
    }];
}

#pragma mark - AwfulPostsViewDelegate

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView
{
    return 1;
}

- (NSDictionary *)postsView:(AwfulPostsView *)postsView postAtIndex:(NSInteger)index
{
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[AwfulPostsViewKeys.innerHTML] = self.privateMessage.innerHTML ?: @"";
    dict[AwfulPostsViewKeys.beenSeen] = self.privateMessage.seen ?: @NO;
    if (self.privateMessage.sentDate) {
        NSDateFormatter *formatter = [AwfulDateFormatters formatters].postDateFormatter;
        dict[AwfulPostsViewKeys.postDate] = [formatter stringFromDate:self.privateMessage.sentDate];
    }
    AwfulUser *sender = self.privateMessage.from;
    dict[AwfulPostsViewKeys.authorName] = sender.username ?: @"";
    if (sender.avatarURL) {
        dict[AwfulPostsViewKeys.authorAvatarURL] = [sender.avatarURL absoluteString];
    }
    if (sender.regdate) {
        NSDateFormatter *formatter = [AwfulDateFormatters formatters].regDateFormatter;
        dict[AwfulPostsViewKeys.authorRegDate] = [formatter stringFromDate:sender.regdate];
    }
    return dict;
}

- (NSArray *)whitelistedSelectorsForPostsView:(AwfulPostsView *)postsView
{
    return @[ @"showActionsForPostAtIndex:fromRectDictionary:" ];
}

- (void)showActionsForPostAtIndex:(NSNumber *)index fromRectDictionary:(NSDictionary *)rectDict
{
    CGRect rect = CGRectMake([rectDict[@"left"] floatValue], [rectDict[@"top"] floatValue],
                             [rectDict[@"width"] floatValue], [rectDict[@"height"] floatValue]);
    if (self.postsView.scrollView.contentOffset.y < 0) {
        rect.origin.y -= self.postsView.scrollView.contentOffset.y;
    }
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
                [self presentViewController:[compose enclosingNavigationController] animated:YES
                                 completion:nil];
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
                [self presentViewController:[compose enclosingNavigationController] animated:YES
                                 completion:nil];
            }
        }];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    [sheet showFromRect:rect inView:self.postsView.window animated:YES];
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
