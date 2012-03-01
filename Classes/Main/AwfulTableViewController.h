//
//  AwfulTableViewController.h
//  Awful
//
//  Created by Sean Berry on 2/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulTableViewController : UITableViewController

@property (nonatomic, strong) NSTimer *refreshTimer;

-(IBAction)refresh;
-(IBAction)stop;
-(void)swapToRefreshButton;
-(void)swapToStopButton;

@end
