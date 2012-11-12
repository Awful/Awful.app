//
//  AwfulSpecificPageController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol AwfulSpecificPageControllerDelegate;

@interface AwfulSpecificPageController : UIViewController

@property (weak, nonatomic) id <AwfulSpecificPageControllerDelegate> delegate;

// Never called automatically. Be sure to call before showing.
- (void)reloadPages;

- (void)showInView:(UIView *)view animated:(BOOL)animated;

- (void)hideAnimated:(BOOL)animated;

@end


@protocol AwfulSpecificPageControllerDelegate <NSObject>

- (NSInteger)numberOfPagesInSpecificPageController:(AwfulSpecificPageController *)controller;

- (NSInteger)currentPageForSpecificPageController:(AwfulSpecificPageController *)controller;

// Sent when a page was chosen.
//
// controller - The specific page controller that accepted a choice.
// page       - The chosen page number. Can be AwfulLast.
- (void)specificPageController:(AwfulSpecificPageController *)controller
                 didSelectPage:(NSInteger)page;

// Sent when a page was not chosen and a touch occured in the containing view.
- (void)specificPageControllerDidCancel:(AwfulSpecificPageController *)controller;

@end
