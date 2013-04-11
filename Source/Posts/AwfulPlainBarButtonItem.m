//
//  AwfulPlainBarButtonItem.m
//  Awful
//
//  Created by Nolan Waite on 2013-04-11.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulPlainBarButtonItem.h"

@implementation AwfulPlainBarButtonItem

#pragma mark - UIBarButtonItem

- (id)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem
                           target:(id)target action:(SEL)action
{
    // Some system items (e.g. UIBarButtonSystemItemReply) unconditionally render with a bordered
    // style in a navigation bar. Embed them in a toolbar first and they're plain.
    UIToolbar *toolbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
    [toolbar setBackgroundImage:[UIImage new]
             forToolbarPosition:UIToolbarPositionAny
                     barMetrics:UIBarMetricsDefault];
    UIBarButtonItem *innerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:systemItem
                                                                               target:target
                                                                               action:action];
    toolbar.items = @[ innerItem ];
    return [self initWithCustomView:toolbar];
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    UIToolbar *toolbar = (id)self.customView;
    [toolbar.items setValue:@(enabled) forKey:@"enabled"];
}

@end
