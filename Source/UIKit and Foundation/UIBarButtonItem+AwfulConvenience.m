//  UIBarButtonItem+AwfulConvenience.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIBarButtonItem+AwfulConvenience.h"
#import <objc/runtime.h>

@interface AwfulActionBlockWrapper : NSObject

@property (copy, nonatomic) void (^block)(UIBarButtonItem *sender);

- (void)invokeBlock:(UIBarButtonItem *)sender;

@end

@implementation UIBarButtonItem (AwfulConvenience)

+ (instancetype)awful_flexibleSpace
{
    return [[self alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
}

+ (instancetype)awful_fixedSpace:(CGFloat)width
{
    UIBarButtonItem *item = [[self alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    item.width = width;
    return item;
}

+ (instancetype)awful_emptyBackBarButtonItem
{
    return [[self alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
}

- (void (^)(UIBarButtonItem *))awful_actionBlock
{
    AwfulActionBlockWrapper *wrapper = objc_getAssociatedObject(self, ActionBlockKey);
    return wrapper.block;
}

- (void)awful_setActionBlock:(void (^)(UIBarButtonItem *))block
{
    AwfulActionBlockWrapper *wrapper;
    if (block) {
        wrapper = [AwfulActionBlockWrapper new];
        wrapper.block = block;
    }
    objc_setAssociatedObject(self, ActionBlockKey, wrapper, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    self.target = wrapper;
    self.action = wrapper ? @selector(invokeBlock:) : nil;
}

static const void * ActionBlockKey = &ActionBlockKey;

@end

@implementation AwfulActionBlockWrapper

- (void)invokeBlock:(UIBarButtonItem *)sender
{
    self.block(sender);
}

@end
