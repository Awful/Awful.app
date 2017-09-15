//
//  UIKit+Extensions.h
//  Awful
//
//  Created by Nolan Waite on 2017-08-03.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

@import UIKit;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AwfulUITextSmartQuotesType) {
    AwfulUITextSmartQuotesTypeDefault,
    AwfulUITextSmartQuotesTypeNo,
    AwfulUITextSmartQuotesTypeYes,
};

@interface UITextView (AwfulExtensions)

/**
 Sets smart quotes type on iOS 11. Does nothing on iOS 10.
 
 @todo If you're building with the iOS 11 SDK and this code still exists, please delete it and use an `if @available` in Swift.
 */
- (void)setSmartQuotesType_awful_iOS10Safe:(AwfulUITextSmartQuotesType)smartQuotesType;

@end

NS_ASSUME_NONNULL_END
