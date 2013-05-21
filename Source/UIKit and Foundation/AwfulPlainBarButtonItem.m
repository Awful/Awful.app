//
//  AwfulPlainBarButtonItem.m
//  Awful
//
//  Created by Nolan Waite on 2013-04-11.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulPlainBarButtonItem.h"

// Some system items (e.g. UIBarButtonSystemItemReply) unconditionally render with a bordered
// style in a navigation bar. Embed them in a toolbar first and they're plain. This class simply
// does this trick and forwards relevant methods to the inner toolbar's item.
@implementation AwfulPlainBarButtonItem

- (UIToolbar *)toolbar
{
    return (id)self.customView;
}

#pragma mark - UIBarButtonItem

- (id)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem
                           target:(id)target action:(SEL)action
{
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    [toolbar setBackgroundImage:[UIImage new]
             forToolbarPosition:UIToolbarPositionAny
                     barMetrics:UIBarMetricsDefault];
    UIBarButtonItem *innerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:systemItem
                                                                               target:target
                                                                               action:action];
    toolbar.items = @[ innerItem ];
    AwfulPlainBarButtonItem *item = [self initWithCustomView:toolbar];
    if (item) {
        // On iPad, toolbar items default to a grey tint color.
        [self setTintColor:[UIColor whiteColor]];
    }
    return item;
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    [self.toolbar.items setValue:@(enabled) forKey:@"enabled"];
}

- (void)setTintColor:(UIColor *)tintColor
{
    [super setTintColor:tintColor];
    [self.toolbar.items setValue:tintColor forKey:@"tintColor"];
}

@end
