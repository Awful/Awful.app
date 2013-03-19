//
//  AwfulSplitViewController.h
//  Awful
//
//  Copyright 2011 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

@interface AwfulSplitViewController : UISplitViewController

- (void)ensureLeftBarButtonItemOnDetailView;

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, nonatomic) UIBarButtonItem *rootPopoverButtonItem;

- (void)showMasterView;

@end
