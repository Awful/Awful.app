//  UISplitViewController+AwfulConvenient.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UISplitViewController+AwfulConvenient.h"

@implementation UISplitViewController (AwfulConvenient)

- (void)awful_showPrimaryViewController
{
    // The docs say that displayMode is "ignored" when we're collapsed. I'm not really sure what that means so let's bail early.
    if (self.collapsed) return;
    
    if (self.displayMode == UISplitViewControllerDisplayModePrimaryHidden) {
        PerformButtonItemAction([self displayModeButtonItem]);
    }
}

- (void)awful_hidePrimaryViewController
{
    // The docs say that displayMode is "ignored" when we're collapsed. I'm not really sure what that means so let's bail early.
    if (self.collapsed) return;
    
    if (self.displayMode == UISplitViewControllerDisplayModePrimaryOverlay) {
        PerformButtonItemAction([self displayModeButtonItem]);
    }
}

static void PerformButtonItemAction(UIBarButtonItem *item)
{
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    
    [item.target performSelector:item.action withObject:nil];
    
    #pragma clang diagnostic pop
}

@end
