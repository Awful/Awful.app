//  AwfulWebViewNetworkActivityIndicatorManager.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
#import <AFNetworking/AFNetworkActivityIndicatorManager.h>

/**
 * An AwfulWebViewNetworkActivityIndicatorManager taps into a UIWebViewDelegate so it works with an AFNetworkActivityIndicatorManager.
 */
@interface AwfulWebViewNetworkActivityIndicatorManager : NSObject <UIWebViewDelegate>

/**
 * Designated initializer.
 */
- (instancetype)initWithManager:(AFNetworkActivityIndicatorManager *)manager nextDelegate:(id<UIWebViewDelegate>)nextDelegate NS_DESIGNATED_INITIALIZER;

/**
 * Calls -initWithManager:nextDelegate: with the shared AFNetworkActivityIndicatorManager.
 */
- (instancetype)initWithNextDelegate:(id<UIWebViewDelegate>)nextDelegate;

/**
 * Calls -initWithNextDelegate: with a nil delegate.
 */
- (instancetype)init;

/**
 * An AFNetworkActivityIndicatorManager to keep apprised.
 */
@property (readonly, strong, nonatomic) AFNetworkActivityIndicatorManager *manager;

/**
 * Another UIWebViewDelegate to forward messages to, or nil if we're the end of the line.
 */
@property (weak, nonatomic) id <UIWebViewDelegate> nextDelegate;

@end
