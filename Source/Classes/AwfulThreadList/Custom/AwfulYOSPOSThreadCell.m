//
//  AwfulYOSPOSThreadCell.m
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulYOSPOSThreadCell.h"

@implementation AwfulYOSPOSThreadCell


-(void)configureForThread:(AwfulThread *)thread {
    [super configureForThread:thread];
    
    UIColor *textColor = [UIColor YOSPOSGreenColor];
    UIColor *bgColor = [UIColor blackColor];
    
    self.backgroundColor =  bgColor;
    self.contentView.backgroundColor = bgColor;
    
    self.threadTitleLabel.textColor = textColor;
    self.threadTitleLabel.font = [UIFont fontWithName:@"Courier" size:16];
    self.threadTitleLabel.backgroundColor = [UIColor clearColor];
    
    self.pagesLabel.textColor = textColor;
    self.pagesLabel.font = [UIFont fontWithName:@"Courier" size:14];
    self.pagesLabel.backgroundColor = [UIColor clearColor];
    
    [self.unreadButton setTitleColor:[UIColor blackColor] forState:(UIControlStateNormal)];
    self.unreadButton.titleLabel.font = [UIFont fontWithName:@"Courier" size:14];
    [self.unreadButton setBackgroundImage:nil forState:UIControlStateNormal];
    self.unreadButton.titleLabel.backgroundColor = textColor;
    [self.unreadButton setBackgroundColor:[UIColor YOSPOSGreenColor]];
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}

-(void) setSelected:(BOOL)selected animated:(BOOL)animated{    
    if (selected) {
        [UIView animateWithDuration:.5
                              delay:0
                            options:(UIViewAnimationOptionAutoreverse|
                                     UIViewAnimationOptionRepeat|
                                     UIViewAnimationOptionCurveEaseInOut) 
                         animations:^{
                             self.contentView.backgroundColor = [UIColor YOSPOSGreenColor];
                         } 
                         completion:^(BOOL finished) {
                             
                         }
         ];
    }
    
    else
        self.contentView.backgroundColor = [UIColor blackColor];
    
    
}


@end


@implementation UIColor (YOSPOS)
+(UIColor*) YOSPOSGreenColor {
    return [UIColor colorWithRed:.224 green:1 blue:.224 alpha:1];
}
@end