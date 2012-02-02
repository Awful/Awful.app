//
//  AwfulSmallPageController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulPage;

@interface AwfulSmallPageController : UIViewController

@property (nonatomic, strong) AwfulPage *page;
@property (nonatomic, strong) IBOutlet UISegmentedControl *segment;
@property (nonatomic, strong) IBOutlet UIButton *forumButton;
@property BOOL hiding;
@property BOOL submitting;

-(id)initWithAwfulPage : (AwfulPage *)aPage;

-(IBAction)selected : (UISegmentedControl *)sender;
-(IBAction)hitNext;
-(IBAction)hitPrev;
-(IBAction)hitFirst;
-(IBAction)hitLast;
-(IBAction)hitForum : (id)sender;

@end
