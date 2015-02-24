//  AwfulNavigationController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulNavigationController.h"
#import "AwfulUnpoppingViewHandler.h"
#import "Awful-Swift.h"

@interface AwfulNavigationController () <UIGestureRecognizerDelegate, UINavigationControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) AwfulUnpoppingViewHandler *unpopHandler;
@property (assign, nonatomic) BOOL pushAnimationInProgress;

@property (weak, nonatomic) id <UINavigationControllerDelegate> realDelegate;

@end

@implementation AwfulNavigationController

// We cannot override the designated initializer, -initWithNibName:bundle:, and call -initWithNavigationBarClass:toolbarClass: within. So we override what we can, and handle our own restoration, to ensure our navigation bar and toolbar classes are used.

- (id)init
{
    if ((self = [self initWithNavigationBarClass:[AwfulNavigationBar class] toolbarClass:[AwfulToolbar class]])) {
        self.restorationClass = self.class;
        super.delegate = self;
    }
    return self;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController
{
    if ((self = [self init])) {
        self.viewControllers = @[ rootViewController ];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self themeDidChange];
    self.interactivePopGestureRecognizer.delegate = self;
}

- (void)themeDidChange
{
    [super themeDidChange];
    Theme *theme = [Theme currentTheme];
    self.navigationBar.tintColor = theme[@"navigationBarTextColor"];
    self.navigationBar.barTintColor = theme[@"navigationBarTintColor"];
    self.toolbar.tintColor = theme[@"toolbarTextColor"];
    self.toolbar.barTintColor = theme[@"toolbarTintColor"];
}

#pragma mark - UIViewControllerRestoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    UINavigationController *nav = [self new];
    nav.restorationIdentifier = identifierComponents.lastObject;
    return nav;
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.unpopHandler.viewControllers = [coder decodeObjectForKey:FutureViewControllersKey];
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.unpopHandler.viewControllers forKey:FutureViewControllersKey];
}

static NSString * const FutureViewControllersKey = @"AwfulFutureViewControllers";

#pragma mark - Swipe to unpop

- (AwfulUnpoppingViewHandler *)unpopHandler
{
    if (!_unpopHandler && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        _unpopHandler = [[AwfulUnpoppingViewHandler alloc] initWithNavigationController:self];
    }
    return _unpopHandler;
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    UIViewController *viewController = [super popViewControllerAnimated:animated];
    [self.unpopHandler navigationController:self didPopViewController:viewController];
    return viewController;
}

- (NSArray *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    NSArray *popped = [super popToViewController:viewController animated:animated];
    for (UIViewController *viewController in popped) {
        [self.unpopHandler navigationController:self didPopViewController:viewController];
    }
    return popped;
}

- (NSArray *)popToRootViewControllerAnimated:(BOOL)animated
{
    NSArray *popped = [super popToRootViewControllerAnimated:animated];
    for (UIViewController *viewController in popped) {
        [self.unpopHandler navigationController:self didPopViewController:viewController];
    }
    return popped;
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    self.pushAnimationInProgress = YES;
    [super pushViewController:viewController animated:animated];
    [self.unpopHandler navigationController:self didPushViewController:viewController];
}

#pragma mark - UINavigationControllerDelegate

- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    [self setToolbarHidden:(viewController.toolbarItems.count == 0) animated:animated];
    
    if (animated) {
        [self.unpopHandler navigationControllerDidBeginAnimating];
        
        // We need to hook into the transitionCoordinator's notifications as well as -...didShowViewController: because the latter isn't called when the default interactive pop action is cancelled.
        // See http://stackoverflow.com/questions/23484310
        id <UIViewControllerTransitionCoordinator> coordinator = navigationController.transitionCoordinator;
        [coordinator notifyWhenInteractionEndsUsingBlock:^(id <UIViewControllerTransitionCoordinatorContext> context) {
            if ([context isCancelled]) {
                BOOL unpopping = self.unpopHandler.interactiveUnpopIsTakingPlace;
                NSTimeInterval completion = [context transitionDuration] * [context percentComplete];
                NSUInteger viewControllerCount = navigationController.viewControllers.count;
                if (!unpopping) viewControllerCount++;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (uint64_t)completion * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    if (unpopping) {
                        [self.unpopHandler navigationControllerDidCancelInteractiveUnpop];
                    } else {
                        [self.unpopHandler navigationControllerDidCancelInteractivePop];
                    }
                    self.pushAnimationInProgress = NO;
                });
            }
        }];

    }
    
    if ([self.realDelegate respondsToSelector:_cmd]) {
        [self.realDelegate navigationController:navigationController willShowViewController:viewController animated:animated];
    }
}

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    if (animated) [self.unpopHandler navigationControllerDidFinishAnimating];
    self.pushAnimationInProgress = NO;
    
    if ([self.realDelegate respondsToSelector:_cmd]) {
        [self.realDelegate navigationController:navigationController didShowViewController:viewController animated:animated];
    }
}

- (id <UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                          interactionControllerForAnimationController:(id <UIViewControllerAnimatedTransitioning>)animationController
{
    if (self.unpopHandler) {
        return self.unpopHandler;
    } else if ([self.realDelegate respondsToSelector:_cmd]) {
        return [self.realDelegate navigationController:navigationController interactionControllerForAnimationController:animationController];
    } else {
        return nil;
    }
}

- (id <UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController
                                   animationControllerForOperation:(UINavigationControllerOperation)operation
                                                fromViewController:(UIViewController *)fromVC
                                                  toViewController:(UIViewController *)toVC
{
    if ([self.unpopHandler shouldHandleAnimatingTransitionForOperation:operation]) {
        return self.unpopHandler;
    } else if ([self.realDelegate respondsToSelector:_cmd]) {
        return [self.realDelegate navigationController:navigationController
                       animationControllerForOperation:operation
                                    fromViewController:fromVC
                                      toViewController:toVC];
    } else {
        return nil;
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    // Disable swipe-to-pop gesture recognizer during pop animations and when we have nothing to pop. If we don't do this, something bad happens in conjunction with the swipe-to-unpop that causes a pushed view controller not to actually appear on the screen. It looks like the app has simply frozen.
    // See http://holko.pl/ios/2014/04/06/interactive-pop-gesture/ for more, and https://github.com/fastred/AHKNavigationController for the fix.
    return self.viewControllers.count > 1 && !self.pushAnimationInProgress;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    // Allow simultaneous recognition with:
    //   1. The swipe-to-unpop gesture recognizer.
    //   2. The swipe-to-show-basement gesture recognizer.
    return [otherGestureRecognizer isKindOfClass:[UIScreenEdgePanGestureRecognizer class]];
}

#pragma mark - Delegate delegation

- (void)setDelegate:(id <UINavigationControllerDelegate>)delegate
{
    super.delegate = nil;
    if (delegate == self) {
        self.realDelegate = nil;
    } else {
        self.realDelegate = delegate;
        super.delegate = self;
    }
}

- (BOOL)respondsToSelector:(SEL)selector
{
    return [super respondsToSelector:selector] || [self.realDelegate respondsToSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
    return [super methodSignatureForSelector:selector] ?: [(id)self.realDelegate methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
    id realDelegate = self.realDelegate;
    if ([realDelegate respondsToSelector:invocation.selector]) {
        [invocation invokeWithTarget:realDelegate];
    }
}

@end
