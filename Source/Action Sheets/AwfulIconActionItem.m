//
//  AwfulIconActionItem.m
//  Awful
//
//  Created by Nolan Waite on 2013-04-25.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulIconActionItem.h"

@implementation AwfulIconActionItem

- (id)initWithTitle:(NSString *)title
               icon:(UIImage *)icon
          tintColor:(UIColor *)tintColor
             action:(void (^)(void))action
{
    if (!(self = [super init])) return nil;
    self.title = title;
    self.icon = icon;
    self.tintColor = tintColor;
    self.action = action;
    return self;
}

@end
