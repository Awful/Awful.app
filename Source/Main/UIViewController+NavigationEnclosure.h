//
//  UIViewController+NavigationEnclosure.h
//  Awful
//
//  Created by Nolan Waite on 2012-11-07.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIViewController (NavigationEnclosure)

// Gets this view controller's navigation controller, lazily creating one if needed.
@property (readonly, nonatomic) UINavigationController *enclosingNavigationController;

@end
