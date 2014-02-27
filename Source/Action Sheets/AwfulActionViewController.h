//  AwfulActionViewController.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSemiModalViewController.h"
#import "AwfulIconActionItem.h"

/**
 * An AwfulActionViewController shows actions in a scrollable grid of icons, with an optional title.
 */
@interface AwfulActionViewController : AwfulSemiModalViewController

@property (copy, nonatomic) NSArray *items;

- (void)addItem:(AwfulIconActionItem  *)item;

@end
