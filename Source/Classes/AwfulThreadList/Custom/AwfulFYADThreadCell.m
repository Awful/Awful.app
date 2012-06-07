//
//  AwfulFYADThreadCell.m
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFYADThreadCell.h"

@implementation AwfulFYADThreadCell


-(void)configureForThread:(AwfulThread *)thread {
    [super configureForThread:thread];
    
    UIColor *textColor = [UIColor blackColor];
    UIColor *bgColor = [UIColor colorWithRed:1 green:.8 blue:1 alpha:1];
    
    self.backgroundColor =  bgColor;
    self.contentView.backgroundColor = bgColor;
    
    self.threadTitleLabel.textColor = textColor;
    self.threadTitleLabel.font = [UIFont fontWithName:@"Courier" size:16];
    self.threadTitleLabel.backgroundColor = bgColor;
    
    self.pagesLabel.textColor = textColor;
    self.pagesLabel.font = [UIFont fontWithName:@"Courier" size:14];
    self.pagesLabel.backgroundColor = bgColor;
    
    self.unreadButton.titleLabel.textColor = textColor;
}
@end
