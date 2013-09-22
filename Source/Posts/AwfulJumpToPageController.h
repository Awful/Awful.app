//  AwfulJumpToPageController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulThreadPage.h"
@protocol AwfulJumpToPageControllerDelegate;

/**
 * A page picker with navigation bar item shortcuts for first page and last page.
 */
@interface AwfulJumpToPageController : AwfulViewController

/**
 * Returns an initialized AwfulJumpToPageController. This is the designated initializer.
 */
- (id)initWithDelegate:(id <AwfulJumpToPageControllerDelegate>)delegate;

/**
 * The delegate.
 */
@property (weak, nonatomic) id <AwfulJumpToPageControllerDelegate> delegate;

/**
 * The total number of pages to show in the picker. Default is one.
 */
@property (assign, nonatomic) NSInteger numberOfPages;

/**
 * The currently-selected page, one-indexed. Default is one.
 */
@property (assign, nonatomic) NSInteger selectedPage;

@end

/**
 * An AwfulJumpToPageControllerDelegate is informed when a page is selected.
 */
@protocol AwfulJumpToPageControllerDelegate <NSObject>

/**
 * Informs the delegate that a page was selected.
 *
 * @param jump The controller that chose a page.
 * @param page The chosen page. May be AwfulThreadPageLast.
 */
- (void)jumpToPageController:(AwfulJumpToPageController *)jump didSelectPage:(AwfulThreadPage)page;

@end
