//  AwfulUnpoppingViewHandler.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import UIKit;

@protocol AwfulNavigationControllerObserver <NSObject>

- (void)navigationController:(UINavigationController *)navigationController
        didPopViewController:(UIViewController *)viewController;

- (void)navigationController:(UINavigationController *)navigationController
       didPushViewController:(UIViewController *)viewController;
@end


@interface AwfulUnpoppingViewHandler : UIPercentDrivenInteractiveTransition <AwfulNavigationControllerObserver, UIGestureRecognizerDelegate,
     UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning>

- (instancetype)initWithNavigationController:(UINavigationController *)navigationController;

- (void)navigationControllerBeganAnimating:(UINavigationController *)navigationController;
- (void)navigationControllerFinishedAnimating:(UINavigationController *)navigationController;

- (BOOL)shouldHandleAnimatingTransitionForOperation:(UINavigationControllerOperation)operation;

@property (copy, nonatomic) NSArray *viewControllers;

@end
