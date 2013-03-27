//
//  AwfulJumpToPageController.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>
#import "AwfulThreadPage.h"
@protocol AwfulJumpToPageControllerDelegate;

@interface AwfulJumpToPageController : UIViewController

// Designated initializer.
- (instancetype)initWithDelegate:(id <AwfulJumpToPageControllerDelegate>)delegate;

@property (weak, nonatomic) id <AwfulJumpToPageControllerDelegate> delegate;

// These both default to one.
@property (nonatomic) NSInteger numberOfPages;
@property (nonatomic) NSInteger selectedPage;

// On iPhone, darkens the viewController's view and slides the jump to page controller up from the
// bottom.
//
// On iPad, shows the jump to page controller in a popover pointing at the given view. If the
// interface orientation changes, the popover is repositioned to continue pointing at the given view
// (unless the view is not in a window, in which case the popover is dismissed).
- (void)presentFromViewController:(UIViewController *)viewController fromView:(UIView *)view;

// Remove the jump to page controller from the screen. No delegate methods are called as a result.
//
// On iPad, this method is called when the popover is dismissed by tapping elsewhere on the screen.
- (void)dismiss;

@end


@protocol AwfulJumpToPageControllerDelegate <NSObject>

- (void)jumpToPageController:(AwfulJumpToPageController *)jump didSelectPage:(AwfulThreadPage)page;

@end
