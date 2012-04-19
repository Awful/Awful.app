//
//  AwfulSettingsViewController.h
//  Awful
//
//  Created by Sean Berry on 3/1/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"

@interface AwfulSettingsViewController : AwfulTableViewController <UIAlertViewDelegate>

@property (strong, nonatomic) IBOutlet UILabel *usernameLabel;

- (IBAction)resetData:(id)sender;

@end
