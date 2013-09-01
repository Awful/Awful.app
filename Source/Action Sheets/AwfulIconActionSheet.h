//  AwfulIconActionSheet.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSemiModalViewController.h"
#import "AwfulIconActionItem.h"

// Shows actions as a grid of icons, in a style inspired by UIActionSheet.
@interface AwfulIconActionSheet : AwfulSemiModalViewController

// Add an item to an icon action sheet.
- (void)addItem:(AwfulIconActionItem *)item;

@end
