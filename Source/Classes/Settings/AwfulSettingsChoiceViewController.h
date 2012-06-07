//
//  AwfulSettingsChoiceViewController.h
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulSettingsViewController;

@interface AwfulSettingsChoiceViewController : UITableViewController

- (id)initWithSetting:(NSDictionary *)setting selectedValue:(id)selectedValue;

@property (readonly, strong) NSDictionary *setting;

@property (readonly, weak) id selectedValue;

@property (weak) AwfulSettingsViewController *settingsViewController;

@end
