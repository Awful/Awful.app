//
//  UIKit+Extensions.h
//  Awful
//
//  Created by Nolan Waite on 2017-08-03.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface UITextView (AwfulExtensions)

/**
 Executes `block` with smart quotes turned off, then restores `smartQuotesType` to its original value.

 `smartQuotesType` is introduced in iOS 11 but we're still building with the iOS 10 SDK, yet smart quotes wreak havoc with BBcode on iOS 11 beta. So here we do runtime magic to temporarily turn off smart quotes if we're on iOS 11, and if we're on iOS 10 we simply execute `block`.
 
 TODO: If you're building with the iOS 11 SDK and this code still exists, please delete it and use an `if @available` in Swift.
 */
- (void)withoutSmartQuotes:(__attribute__((noescape)) void (^)(UITextView *textView))block;

@end

NS_ASSUME_NONNULL_END
