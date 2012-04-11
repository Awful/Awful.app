//
//  AwfulAddForumsViewController.h
//  Awful
//
//  Created by Sean Berry on 4/4/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumsListController.h"

@interface AwfulAddForumsViewController : AwfulForumsListController

@property (nonatomic, weak) IBOutlet AwfulForumsListController *delegate;

-(IBAction)hitDone:(id)sender;

@end
