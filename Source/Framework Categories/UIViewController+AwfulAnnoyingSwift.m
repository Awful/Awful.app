//  UIViewController+AwfulAnnoyingSwift.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulAnnoyingSwift.h"

@implementation UIViewController (AwfulAnnoyingSwift)

- (void)awful_clearRestorationClass
{
    self.restorationClass = nil;
}

@end
