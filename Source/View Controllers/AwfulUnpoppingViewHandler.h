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


@interface AwfulUnpoppingViewHandler : UIPercentDrivenInteractiveTransition <AwfulNavigationControllerObserver,
     UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning>

- (instancetype)initWithNavigationController:(UINavigationController *)navigationController;

@property (readonly, weak, nonatomic) UINavigationController *navigationController;
@property (readonly, nonatomic) BOOL interactiveUnpopIsTakingPlace;

- (void)navigationControllerDidBeginAnimating;
- (void)navigationControllerDidFinishAnimating;
- (void)navigationControllerDidCancelInteractivePop;
- (void)navigationControllerDidCancelInteractiveUnpop;

- (BOOL)shouldHandleAnimatingTransitionForOperation:(UINavigationControllerOperation)operation;

@property (copy, nonatomic) NSArray *viewControllers;

@end
