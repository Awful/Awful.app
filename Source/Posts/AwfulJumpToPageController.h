//
//  AwfulJumpToPageController.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulSemiModalViewController.h"
#import "AwfulThreadPage.h"
@protocol AwfulJumpToPageControllerDelegate;

@interface AwfulJumpToPageController : AwfulSemiModalViewController

// Designated initializer.
- (instancetype)initWithDelegate:(id <AwfulJumpToPageControllerDelegate>)delegate;

@property (weak, nonatomic) id <AwfulJumpToPageControllerDelegate> delegate;

// These both default to one.
@property (nonatomic) NSInteger numberOfPages;
@property (nonatomic) NSInteger selectedPage;

@end


@protocol AwfulJumpToPageControllerDelegate <NSObject>
@property (copy, nonatomic) NSString *userID;
- (void)jumpToPageController:(AwfulJumpToPageController *)jump didSelectPage:(AwfulThreadPage)page;

@end
