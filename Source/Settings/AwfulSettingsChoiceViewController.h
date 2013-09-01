//
//  AwfulSettingsChoiceViewController.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import <UIKit/UIKit.h>

@interface AwfulSettingsChoiceViewController : UITableViewController

- (id)initWithSetting:(NSDictionary *)setting;

@property (readonly, strong) NSDictionary *setting;

@end
