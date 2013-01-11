//
//  AwfulSettingsChoiceViewController.h
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulSettingsChoiceViewController : UITableViewController

- (id)initWithSetting:(NSDictionary *)setting;

@property (readonly, strong) NSDictionary *setting;

@end
