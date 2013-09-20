//  AwfulRapSheetViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulRapSheetViewController.h"
#import "AwfulUser.h"


@interface AwfulRapSheetViewController ()

@property (nonatomic) AwfulUser *user;

@end


@implementation AwfulRapSheetViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.modalPresentationStyle = UIModalPresentationFormSheet;
    return self;
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

@end
