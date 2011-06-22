//
//  AwfulTableViewController.h
//  Awful
//
//  Created by Regular Berry on 6/21/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulPageCount;
@class AwfulNavigator;

@interface AwfulTableViewController : UITableViewController {
    AwfulPageCount *_pages;
    AwfulNavigator *_delegate;
    UILabel *_pagesLabel;
    UILabel *_forumLabel;
    UILabel *_threadTitleLabel;
}

@property (nonatomic, retain) AwfulPageCount *pages;
@property (nonatomic, assign) AwfulNavigator *delegate;
@property (nonatomic, retain) IBOutlet UILabel *pagesLabel;
@property (nonatomic, retain) IBOutlet UILabel *forumLabel;
@property (nonatomic, retain) IBOutlet UILabel *threadTitleLabel;

-(void)refresh;
-(void)stop;

@end
