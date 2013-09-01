//
//  AwfulJumpToPageController.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import <UIKit/UIKit.h>
#import "AwfulThreadPage.h"
@protocol AwfulJumpToPageControllerDelegate;

@interface AwfulJumpToPageController : UIViewController

// Designated initializer.
- (id)initWithDelegate:(id <AwfulJumpToPageControllerDelegate>)delegate;

@property (weak, nonatomic) id <AwfulJumpToPageControllerDelegate> delegate;

// These both default to one.
@property (nonatomic) NSInteger numberOfPages;
@property (nonatomic) NSInteger selectedPage;

@end


@protocol AwfulJumpToPageControllerDelegate <NSObject>

- (void)jumpToPageController:(AwfulJumpToPageController *)jump didSelectPage:(AwfulThreadPage)page;

@end
