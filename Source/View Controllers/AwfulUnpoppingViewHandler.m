//  AwfulUnpoppingViewHandler.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulUnpoppingViewHandler.h"

@interface AwfulUnpoppingViewHandler ()

@property (weak, nonatomic) UINavigationController *navigationController;
@property (assign, nonatomic) BOOL navigationControllerIsAnimating;
@property (strong, nonatomic) NSMutableArray *controllerStack;

@property (strong, nonatomic) UIScreenEdgePanGestureRecognizer *panRecognizer;
@property (assign, nonatomic) CGFloat gestureStartPointX;
@property (assign, nonatomic) BOOL interactiveTransitionIsTakingPlace;

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
      
        self.navigationController.interactivePopGestureRecognizer.delegate = self;
      
        self.controllerStack = [NSMutableArray array];
    }
    return self;
}

- (void)navigationControllerBeganAnimating:(UINavigationController *)navigationController
{
    self.navigationControllerIsAnimating = YES;
}

- (void)navigationControllerFinishedAnimating:(UINavigationController *)navigationController
{
    self.navigationControllerIsAnimating = NO;
}

- (BOOL)shouldHandleAnimatingTransitionForOperation:(UINavigationControllerOperation)operation
{
    return (operation == UINavigationControllerOperationPush && self.interactiveTransitionIsTakingPlace);
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
                self.interactiveTransitionIsTakingPlace = YES;
                self.gestureStartPointX = point.x;
                [self.navigationController pushViewController:self.controllerStack.lastObject animated:YES];
            }
            break;
        }
        case UIGestureRecognizerStateChanged: {
            if (self.interactiveTransitionIsTakingPlace) {
                CGFloat percent = (self.gestureStartPointX - point.x) / self.gestureStartPointX;
                [self updateInteractiveTransition:percent];
            }
            break;
        }
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded: {
            if (self.interactiveTransitionIsTakingPlace) {
                CGFloat percent = (self.gestureStartPointX - point.x) / self.gestureStartPointX;
                // TODO: Use [recognizer velocityInView] too?
                if (percent <= 0.3) {
                    [self cancelInteractiveTransition];
                } else {
                    [self.controllerStack removeLastObject];
                    [self finishInteractiveTransition];
                }
                self.gestureStartPointX = 0;
                self.interactiveTransitionIsTakingPlace = NO;
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
    } else {
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    return !self.navigationControllerIsAnimating;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    // There's three recognizers here that may need simultaneous recognition:
    //   1. Our own pan from right screen edge.
    //   2. The navigation controller's pan from left screen edge.
    //   3. On iPhone, the basement's pan from left screen edge.
    // As a poor substitute, we'll just allow all screen edge pans to recognize at once.
    if (gestureRecognizer.delegate == self) {
        return [otherGestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]];
    } else if (otherGestureRecognizer.delegate == self) {
        return [gestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]];
    } else {
        return NO;
    }
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
    if (!self.interactiveTransitionIsTakingPlace) {
        [self.controllerStack removeAllObjects];
    }
}

@end
