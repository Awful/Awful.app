//
//  TemplateListViewController.h
//  Awful
//
//  Created by Nolan Waite on 12-05-27.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TemplateListViewController : UITableViewController

// Designated initializer.
- (id)initWithFolder:(NSURL *)folder;

@property (readonly, strong, nonatomic) NSURL *folder;

@end
