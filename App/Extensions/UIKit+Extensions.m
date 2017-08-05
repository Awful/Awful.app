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

- (void)withoutSmartQuotes:(void (^)(UITextView *textView))block {
    // I tried `valueForKey:` first (from Swift) but that throws an exception. Let's try NSInvocation!

    SEL getterSelector = NSSelectorFromString(@"smartQuotesType");
    NSMethodSignature *getterSignature = [self methodSignatureForSelector:getterSelector];
    SEL setterSelector = NSSelectorFromString(@"setSmartQuotesType:");
    NSMethodSignature *setterSignature = [self methodSignatureForSelector:setterSelector];
    if (!getterSignature || !setterSignature) {
        return block(self);
    }

    NSInteger oldSmartQuotesType;
    NSInvocation *getter = [NSInvocation invocationWithMethodSignature:getterSignature];
    getter.selector = getterSelector;
    [getter invokeWithTarget:self];
    [getter getReturnValue:&oldSmartQuotesType];

    NSInteger noSmartQuotes = 1;
    NSInvocation *setter = [NSInvocation invocationWithMethodSignature:setterSignature];
    setter.selector = setterSelector;
    [setter setArgument:&noSmartQuotes atIndex:2];
    [setter invokeWithTarget:self];

    block(self);

    [setter setArgument:&oldSmartQuotesType atIndex:2];
    [setter invokeWithTarget:self];
}

@end

NS_ASSUME_NONNULL_END
