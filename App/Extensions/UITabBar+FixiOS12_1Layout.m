//  UITabBar+FixiOS12_1Layout.m
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UITabBar+FixiOS12_1Layout.h"
@import ObjectiveC.runtime;

@implementation UITabBar (FixiOS12_1Layout)

+ (void)load {
    // `+load` should in theory only get called once, but let's be paranoid.
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // Versions below iOS 12.1 are unaffected, so don't bother them with our swizzling hijinks.
        if (@available(iOS 12.1, *)) {
            Method setFrame = class_getInstanceMethod(NSClassFromString(@"UITabBarButton"), @selector(setFrame:));
            originalSetFrame = method_setImplementation(setFrame, (IMP)swizzledSetFrame);
        }
    });
}

static IMP originalSetFrame;

static void swizzledSetFrame(UITabBar *self, SEL _cmd, CGRect frame) {
    
    // Having interposed ourselves into the `-setFrame:` call, if someone is trying to set our frame to nothing, let's just drop that on the floor.
    if (!CGRectIsEmpty(self.frame) && CGRectIsEmpty(frame)) {
        return;
    }
    
    // OK, this seems like a reasonable frame change, so let's call the original implementation.
    ((void(*)(id, SEL, CGRect))originalSetFrame)(self, _cmd, frame);
}

@end
