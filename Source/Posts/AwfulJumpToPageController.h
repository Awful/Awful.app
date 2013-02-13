//
//  AwfulJumpToPageController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulThreadPage.h"

@protocol AwfulJumpToPageControllerDelegate;


@interface AwfulJumpToPageController : UIViewController

@property (weak, nonatomic) id <AwfulJumpToPageControllerDelegate> delegate;

// Never called automatically. Be sure to call before showing.
- (void)reloadPages;

- (void)showInView:(UIView *)view animated:(BOOL)animated;

- (void)hideAnimated:(BOOL)animated completion:(void (^)(void))completionBlock;

@end


@protocol AwfulJumpToPageControllerDelegate <NSObject>

- (NSInteger)numberOfPagesInJumpToPageController:(AwfulJumpToPageController *)controller;

- (AwfulThreadPage)currentPageForJumpToPageController:(AwfulJumpToPageController *)controller;

- (void)jumpToPageController:(AwfulJumpToPageController *)controller
               didSelectPage:(AwfulThreadPage)page;

@end
