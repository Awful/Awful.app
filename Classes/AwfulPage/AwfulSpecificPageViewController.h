//
//  AwfulSmallPageController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulPage;
@class ButtonSegmentedControl;

@interface AwfulSpecificPageViewController : UIViewController <UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic, weak) AwfulPage *page;
@property BOOL hiding;
@property (nonatomic, strong) IBOutlet UIView *containerView;
@property (nonatomic, strong) IBOutlet UIPickerView *pickerView;

@property (nonatomic, strong) IBOutlet UIBarButtonItem *jumpToPageBarButtonItem;
@property (nonatomic, strong) IBOutlet ButtonSegmentedControl *firstLastSegmentedControl;

-(IBAction)hitJumpToPage:(id)sender;
-(IBAction)hitFirst : (id)sender;
-(IBAction)hitLast : (id)sender;
-(IBAction)hitFirstLastSegment : (id)sender;

@end
