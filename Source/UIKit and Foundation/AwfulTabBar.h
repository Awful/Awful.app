//
//  AwfulTabBar.h
//  Awful
//
//  Created by Nolan Waite on 2012-12-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol AwfulTabBarDelegate;

@interface AwfulTabBar : UIView

@property (copy, nonatomic) NSArray *items;

@property (nonatomic) UITabBarItem *selectedItem;

@property (weak, nonatomic) id <AwfulTabBarDelegate> delegate;

@end


@protocol AwfulTabBarDelegate <NSObject>
@optional

- (void)tabBar:(AwfulTabBar *)tabBar didSelectItem:(UITabBarItem *)item;

@end
