//
//  UIKit+Extensions.m
//  Awful
//
//  Created by Nolan Waite on 2017-08-03.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

#import "UIKit+Extensions.h"

NS_ASSUME_NONNULL_BEGIN

@implementation UITextView (AwfulExtensions)

- (void)setSmartQuotesType_awful_iOS10Safe:(AwfulUITextSmartQuotesType)smartQuotesType {
    // I tried `valueForKey:` first (from Swift) but that throws an exception. Let's try NSInvocation!

    SEL setterSelector = NSSelectorFromString(@"setSmartQuotesType:");
    NSMethodSignature *setterSignature = [self methodSignatureForSelector:setterSelector];
    if (!setterSignature) {
        return;
    }

    NSInvocation *setter = [NSInvocation invocationWithMethodSignature:setterSignature];
    setter.selector = setterSelector;
    [setter setArgument:&smartQuotesType atIndex:2];
    [setter invokeWithTarget:self];
}

@end

NS_ASSUME_NONNULL_END
