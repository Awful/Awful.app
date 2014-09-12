//  AwfulUnpoppingViewHandler.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulUnpoppingViewHandler.h"

@interface AwfulUnpoppingViewHandler () <UIGestureRecognizerDelegate>

@property (weak, nonatomic) UINavigationController *navigationController;
@property (assign, nonatomic) BOOL navigationControllerIsAnimating;
@property (strong, nonatomic) NSMutableArray *controllerStack;

@property (strong, nonatomic) UIScreenEdgePanGestureRecognizer *panRecognizer;
@property (assign, nonatomic) CGFloat gestureStartPointX;

@end

@implementation AwfulUnpoppingViewHandler

- (void)dealloc
{
    [self.navigationController.view removeGestureRecognizer:self.panRecognizer];
}

- (instancetype)initWithNavigationController:(UINavigationController *)navigationController
{
    if (self = [super init]) {
        self.navigationController = navigationController;
        
        self.panRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
        self.panRecognizer.edges = UIRectEdgeRight;
        self.panRecognizer.delegate = self;
        [self.navigationController.view addGestureRecognizer:self.panRecognizer];
      
        self.controllerStack = [NSMutableArray array];
    }
    return self;
}

- (void)navigationControllerDidBeginAnimating
{
    self.navigationControllerIsAnimating = YES;
}

- (void)navigationControllerDidFinishAnimating
{
    self.navigationControllerIsAnimating = NO;
}

- (void)navigationControllerDidCancelInteractivePop
{
    // We get a call to didPopViewController when the interactive pop
    // starts, but no (automatic) inverse call if the gesture is cancelled.
    // This cleans up the state by removing the falsely stacked controller.
    self.navigationControllerIsAnimating = NO;
    [self.controllerStack removeLastObject];
}

- (void)navigationControllerDidCancelInteractiveUnpop
{
    self.navigationControllerIsAnimating = NO;
}

- (BOOL)shouldHandleAnimatingTransitionForOperation:(UINavigationControllerOperation)operation
{
    return (operation == UINavigationControllerOperationPush && self.interactiveUnpopIsTakingPlace);
}

- (NSArray *)viewControllers
{
    return [self.controllerStack copy];
}

- (void)setViewControllers:(NSArray *)viewControllers
{
    [self.controllerStack setArray:viewControllers];
}

#pragma mark - Gesture handling

- (void)handlePan:(UIPanGestureRecognizer*)recognizer
{
    const CGPoint point = [recognizer locationInView:recognizer.view];
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan: {
            if (self.controllerStack.count) {
                _interactiveUnpopIsTakingPlace = YES;
                self.gestureStartPointX = point.x;
                [self.navigationController pushViewController:self.controllerStack.lastObject animated:YES];
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (_interactiveUnpopIsTakingPlace) {
                CGFloat percent = (self.gestureStartPointX - point.x) / self.gestureStartPointX;
                [self updateInteractiveTransition:percent];
            }
            break;
        }
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            if (_interactiveUnpopIsTakingPlace) {
                CGFloat percent = (self.gestureStartPointX - point.x) / self.gestureStartPointX;
                // TODO: Use [recognizer velocityInView] too?
                if (percent <= 0.3) {
                    [self cancelInteractiveTransition];
                } else {
                    [self.controllerStack removeLastObject];
                    [self finishInteractiveTransition];
                }
                self.gestureStartPointX = 0;
                _interactiveUnpopIsTakingPlace = NO;
            }
            break;
        }
        default:
            break;
    }
}

#pragma mark - UIViewControllerInteractiveTransitioning

- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext
{
    // TODO: Can we match this up to the default? Does it matter if it will always be interactive?
    // Only takes effect when the system completes a half-swipe
    return 0.35;
}

- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext
{
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    
    [[transitionContext containerView] addSubview:toViewController.view];
    
    CGRect toTargetFrame = fromViewController.view.frame; // New view should occupy same space as previous
    toViewController.view.frame = CGRectOffset(toTargetFrame, CGRectGetWidth(toTargetFrame), 0);
    
    CGRect fromTargetFrame = fromViewController.view.frame;
    fromTargetFrame = CGRectOffset(fromTargetFrame, -CGRectGetWidth(fromTargetFrame)/3, 0);
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext]
                          delay:0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^
    {
        toViewController.view.frame = toTargetFrame;
        fromViewController.view.frame = fromTargetFrame;
    } completion:^(BOOL finished) {
        [transitionContext completeTransition:![transitionContext transitionWasCancelled]];
    }];
}

- (void)animationEnded:(BOOL)transitionCompleted
{
    if (!transitionCompleted) {
        self.navigationControllerIsAnimating = NO;
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return self.controllerStack.count > 0 && !self.navigationControllerIsAnimating;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    // Allow simultaneous recognition with:
    //   1. The swipe-to-pop gesture recognizer.
    //   2. The swipe-to-show-basement gesture recognizer.
    return [otherGestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]];
}

#pragma mark - AwfulNavigationControllerObserver

- (void)navigationController:(UINavigationController *)navigationController
        didPopViewController:(UIViewController *)viewController
{
    if (viewController) {
        [self.controllerStack addObject:viewController];
    }
}

- (void)navigationController:(UINavigationController *)navigationController
       didPushViewController:(UIViewController *)viewController
{
    if (!self.interactiveUnpopIsTakingPlace) {
        [self.controllerStack removeAllObjects];
    }
}

@end
