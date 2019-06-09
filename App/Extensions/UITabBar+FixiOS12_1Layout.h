//  UITabBar+FixiOS12_1Layout.h
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/**
 Fixes a layout issue introduced in iOS 12.1 when popping a view controller with `hidesBottomBarWhenPushed = YES`. The tab bar buttons all go to zero size during the pop, then suddenly fix themselves after the pop is complete. Two bad things here:
 
 1. The tab bar looks very weird during the pop.
 2. After the tab bar buttons jump back into place, their titles are smushed together and it looks bad forever.
 
 This fix is gross: swizzling `-[UITabBarButton setFrame:]`. Sorry. Contain this as much as possible!
 
 @seealso https://stackoverflow.com/a/53111977/1063051 (thanks!!)
 */
@interface UITabBar (FixiOS12_1Layout)

@end

NS_ASSUME_NONNULL_END
