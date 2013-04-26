//
//  AwfulIconActionSheet.h
//  Awful
//
//  Created by Nolan Waite on 2013-04-25.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulSemiModalViewController.h"
#import "AwfulIconActionItem.h"

// Shows actions as a grid of icons, in a style inspired by UIActionSheet.
@interface AwfulIconActionSheet : AwfulSemiModalViewController

// Add an item to an icon action sheet.
- (void)addItem:(AwfulIconActionItem *)item;

@end
