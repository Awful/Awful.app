//
//  AwfulThemePicker.h
//  Awful
//
//  Created by Nolan Waite on 2013-04-12.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <UIKit/UIKit.h>

// Like a UISegmentedControl but with more customizable segments.
@interface AwfulThemePicker : UIControl

// UISegmentedControlNoSegment is a valid selected index.
@property (nonatomic) NSInteger selectedThemeIndex;

- (void)insertThemeWithColor:(UIColor *)color atIndex:(NSInteger)index;

@end
