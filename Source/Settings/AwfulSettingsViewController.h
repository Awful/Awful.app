//
//  AwfulSettingsViewController.h
//  Awful
//
//  Created by Sean Berry on 3/1/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"

@class AwfulSettingsChoiceViewController;

@interface AwfulSettingsViewController : AwfulTableViewController

- (void)didMakeChoice:(AwfulSettingsChoiceViewController *)choiceViewController;

@end
