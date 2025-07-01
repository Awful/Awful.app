//
//  MRProgressHelper.h
//  MRProgress
//
//  Created by Marius Rackwitz on 14.10.13.
//  Copyright (c) 2013 Marius Rackwitz. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>


static inline CGFloat MRCGFloatCeil(CGFloat);

#if defined(__LP64__) && __LP64__
    static inline CGFloat MRCGFloatCeil(CGFloat x) {
        return ceil(x);
    }
#else
    static inline CGFloat MRCGFloatCeil(CGFloat x) {
        return ceilf(x);
    }
#endif


static inline CGRect MRCenterCGSizeInCGRect(CGSize innerRectSize, CGRect outerRect) {
    CGRect innerRect;
    innerRect.size = innerRectSize;
    innerRect.origin.x = outerRect.origin.x + (outerRect.size.width  - innerRectSize.width)  / 2.0f;
    innerRect.origin.y = outerRect.origin.y + (outerRect.size.height - innerRectSize.height) / 2.0f;
    return innerRect;
}


static inline CGFloat MRRotationForStatusBarOrientation() {
    UIInterfaceOrientation orientation = UIInterfaceOrientationUnknown;
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:[UIWindowScene class]]) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
#if defined(__IPHONE_16_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_16_0
                if (@available(iOS 16.0, *)) {
                    orientation = windowScene.effectiveGeometry.interfaceOrientation;
                } else
#endif
                {
                    #pragma clang diagnostic push
                    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
                    orientation = windowScene.interfaceOrientation;
                    #pragma clang diagnostic pop
                }
                break;
            }
        }
    }

    if (orientation == UIInterfaceOrientationLandscapeLeft) {
        return -M_PI_2;
    } else if (orientation == UIInterfaceOrientationLandscapeRight) {
        return M_PI_2;
    } else if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
        return M_PI;
    }
    return 0;
}
