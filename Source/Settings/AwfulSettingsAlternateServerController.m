//  AwfulSettingsAlternateServerController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSettingsAlternateServerController.h"
#import "AwfulForumsClient.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"

@interface AwfulSettingsAlternateServerController ()

@property (nonatomic) NSIndexPath *currentIndexPath;

@end


@implementation AwfulSettingsAlternateServerController

#pragma mark - UIViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Alternate Server";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 2;
}

static NSString * const AgeOldSomethingAwfulIPAddress = @"216.86.148.111";

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:Identifier];
    }
    if (indexPath.row == 0) {
        cell.textLabel.text = @"forums.somethingawful.com";
        if (![AwfulSettings settings].customBaseURL) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            self.currentIndexPath = indexPath;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    } else {
        cell.textLabel.text = AgeOldSomethingAwfulIPAddress;
        if ([[AwfulSettings settings].customBaseURL isEqual:AgeOldSomethingAwfulIPAddress]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
            self.currentIndexPath = indexPath;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    AwfulTheme *theme = self.theme;
    cell.backgroundColor = theme[@"listBackgroundColor"];
    cell.textLabel.textColor = theme[@"listTextColor"];
    if (!cell.selectedBackgroundView) cell.selectedBackgroundView = [UIView new];
    cell.selectedBackgroundView.backgroundColor = theme[@"listSelectedBackgroundColor"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath isEqual:self.currentIndexPath]) return;
    if (indexPath.row == 0) {
        [AwfulSettings settings].customBaseURL = nil;
    } else {
        // Copy the SA cookies over to its standard IP address so we don't have to log in again.
        // I guess if the Forums moves to another IP address someday this would allow someone to
        // hijack SA sessions?
        NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
        NSURL *url = [NSURL URLWithString:@"http://forums.somethingawful.com"];
        for (NSHTTPCookie *cookie in [storage cookiesForURL:url]) {
            NSMutableDictionary *properties = [[cookie properties] mutableCopy];
            properties[NSHTTPCookieDomain] = AgeOldSomethingAwfulIPAddress;
            [storage setCookie:[NSHTTPCookie cookieWithProperties:properties]];
        }
        [AwfulSettings settings].customBaseURL = AgeOldSomethingAwfulIPAddress;
    }
    // TODO allow entering any old hostname or IP address.
    UITableViewCell *oldCell = [tableView cellForRowAtIndexPath:self.currentIndexPath];
    oldCell.accessoryType = UITableViewCellAccessoryNone;
    UITableViewCell *newCell = [tableView cellForRowAtIndexPath:indexPath];
    newCell.accessoryType = UITableViewCellAccessoryCheckmark;
    self.currentIndexPath = indexPath;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // Refresh everything after changing servers.
    [[AwfulRefreshMinder minder] forgetEverything];
}

@end
