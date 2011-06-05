//
//  Stylin.m
//  Awful
//
//  Created by Sean Berry on 11/16/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "Stylin.h"


@implementation Stylin

+(UIView *)newCustomNavbarTitleWithText : (NSString *)in_text
{
    UIFont *f = [UIFont fontWithName:@"Helvetica-Bold" size:22.0];

    UILabel *forum_label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 50)];
    forum_label.font = f;
    forum_label.text = in_text;
    forum_label.adjustsFontSizeToFitWidth = YES;
    forum_label.textAlignment = UITextAlignmentCenter;
    forum_label.textColor = [UIColor whiteColor];
    forum_label.backgroundColor = [UIColor clearColor];
    
    UIView *custom_title = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 50)];
    custom_title.backgroundColor = [UIColor clearColor];
    [custom_title addSubview:forum_label];
    [forum_label release];
    return custom_title;
}

@end