//  AwfulRapSheetViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulRapSheetViewController.h"
#import "AwfulUser.h"


@interface AwfulRapSheetViewController ()

@property (nonatomic) AwfulUser *user;
@property (nonatomic) UILabel *goodUserLabel;

@end


@implementation AwfulRapSheetViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.modalPresentationStyle = UIModalPresentationFormSheet;
    return self;
}

- (void) viewDidLoad
{
    [super viewDidLoad];

    // Hide separators after the last cell.
    self.tableView.tableFooterView = [UIView new];
    self.tableView.tableFooterView.backgroundColor = [UIColor clearColor];
}

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

- (void)refresh
{
    [super refresh];
    self.title = self.user.username;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
    [super tableView:tableView didSelectRowAtIndexPath:indexPath];
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfBans = [super tableView:tableView numberOfRowsInSection:section];

    if (!numberOfBans && self.refreshing) {
        self.tableView.scrollEnabled = NO;
        [self.view addSubview:self.goodUserLabel];
        self.goodUserLabel.frame = self.view.bounds;
    } else {
        self.tableView.scrollEnabled = YES;
        [self.goodUserLabel removeFromSuperview];
    }

    return numberOfBans;
}

- (UILabel*) goodUserLabel
{
    if (_goodUserLabel) return _goodUserLabel;
    _goodUserLabel = [[UILabel alloc] init];
    _goodUserLabel.frame = self.view.bounds;
    _goodUserLabel.text = @"This user has no ban history!";
    _goodUserLabel.textAlignment = NSTextAlignmentCenter;
    return _goodUserLabel;
}

@end
