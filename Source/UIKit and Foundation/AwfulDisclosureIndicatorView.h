//
//  AwfulDisclosureIndicatorView.h
//  Awful
//
//  Created by Nolan Waite on 2012-12-04.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulDisclosureIndicatorView : UIView

@property (nonatomic) UIColor *color;

@property (nonatomic) UIColor *highlightedColor;

// We draw differently when the cell is highlighted.
@property (weak, nonatomic) UITableViewCell *cell;

@end
