#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "GRMustacheKeyAccess.h"
#import "Mustache.h"

FOUNDATION_EXPORT double MustacheVersionNumber;
FOUNDATION_EXPORT const unsigned char MustacheVersionString[];

