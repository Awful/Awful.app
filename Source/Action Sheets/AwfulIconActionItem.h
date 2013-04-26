//
//  AwfulIconActionItem.h
//  Awful
//
//  Created by Nolan Waite on 2013-04-25.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulIconActionItem : NSObject

- (id)initWithTitle:(NSString *)title
               icon:(UIImage *)icon
          tintColor:(UIColor *)tintColor
             action:(void (^)(void))action;

@property (copy, nonatomic) NSString *title;
@property (nonatomic) UIImage *icon;
@property (nonatomic) UIColor *tintColor;
@property (copy, nonatomic) void (^action)(void);

@end
