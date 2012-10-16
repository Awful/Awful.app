//
//  AwfulSpecificPageViewController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulPage;
@class ButtonSegmentedControl;

@interface AwfulSpecificPageViewController : UIViewController

@property (nonatomic, weak) AwfulPage *page;
@property (nonatomic) BOOL hiding;
@property (nonatomic) UIPickerView *pickerView;

@property (nonatomic) UIBarButtonItem *jumpToPageBarButtonItem;
@property (nonatomic) ButtonSegmentedControl *firstLastSegmentedControl;

-(IBAction)hitJumpToPage:(id)sender;
-(IBAction)hitFirst : (id)sender;
-(IBAction)hitLast : (id)sender;
-(IBAction)hitFirstLastSegment : (id)sender;

@end
