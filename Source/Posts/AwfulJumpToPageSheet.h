//
//  AwfulJumpToPageSheet.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulThreadPage.h"

@protocol AwfulJumpToPageSheetDelegate;


@interface AwfulJumpToPageSheet : UIView

// Designated initializer.
- (instancetype)initWithDelegate:(id <AwfulJumpToPageSheetDelegate>)delegate;

@property (weak, nonatomic) id <AwfulJumpToPageSheetDelegate> delegate;

// Displays a jump to page sheet.
//
// On iPhone, this method displays the jump to page sheet within the specified view, behind the
// given subview.
// On iPad, this method displays the jump to page sheet in a popover that points to the given
// subview. The specified view is ignored.
//
// On iPad, the popover's location is not adjusted when the device rotates. If needed, call this
// method when the interface orientation changes, e.g. from your view controller.
- (void)showInView:(UIView *)view behindSubview:(UIView *)subview;

// Immediately dismisses the jump to page sheet. The jump to page sheet calls this method itself
// when a page is selected, after notifying the delegate of the selection.
- (void)dismiss;

@end


@protocol AwfulJumpToPageSheetDelegate <NSObject>

- (NSInteger)numberOfPagesInJumpToPageSheet:(AwfulJumpToPageSheet *)sheet;

- (AwfulThreadPage)initialPageForJumpToPageSheet:(AwfulJumpToPageSheet *)sheet;

- (void)jumpToPageSheet:(AwfulJumpToPageSheet *)sheet didSelectPage:(AwfulThreadPage)page;

@end
