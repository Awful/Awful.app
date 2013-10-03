//  AwfulRapSheetViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulRapSheetViewController.h"
#import "AwfulUser.h"

@implementation AwfulRapSheetViewController

- (id)initWithUser:(AwfulUser *)user
{
    if (!(self = [super init])) return nil;
    _user = user;
    self.modalPresentationStyle = UIModalPresentationFormSheet;
    return self;
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
