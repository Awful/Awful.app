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
// Creating a navigation controller also sets its modalPresentationStyle to that of this view
// controller.
@property (readonly, nonatomic) UINavigationController *enclosingNavigationController;

@end
