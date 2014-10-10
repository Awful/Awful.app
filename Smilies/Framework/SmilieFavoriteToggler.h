//  SmilieFavoriteToggler.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;
@class Smilie;

@interface SmilieFavoriteToggler : UIViewController

- (instancetype)initWithSmilie:(Smilie *)smilie pointingAtView:(UIView *)targetView;

@property (readonly, strong, nonatomic) Smilie *smilie;
@property (readonly, weak, nonatomic) UIView *targetView;

@end
