//
//  AwfulPageIpad.h
//  Awful
//
//  Created by Sean Berry on 3/13/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPage.h"

@class AwfulActions;

@interface AwfulPageIpad : AwfulPage <UIPickerViewDataSource, UIPickerViewDelegate>

@property (nonatomic, strong) IBOutlet UIBarButtonItem *listBarButtonItem;
@property (nonatomic, strong) UIBarButtonItem *pageButton;
@property (nonatomic, strong) UIBarButtonItem *ratingButton;
@property (nonatomic, strong) UIPopoverController *popController;
@property (nonatomic, strong) UIPickerView *pagePicker;
@property CGPoint lastTouch;
@property (nonatomic, strong) AwfulActions *actions;
@property (nonatomic, strong) UIPopoverController *popOverController;

-(IBAction)tappedList : (id)sender;

-(void)makeCustomToolbars;
-(void)hitActions;
-(void)hitMore;
-(void)pageSelection;
-(void)gotoPageClicked;
-(void)hitForum;
-(void)handleTap:(UITapGestureRecognizer *)sender;
-(void)rateThread:(id)sender;
-(void)bookmarkThread:(id)sender;
-(void)reply;
-(void)backPage;

@end