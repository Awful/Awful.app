//
//  AwfulAskTellThreadCell.m
//  Awful
//
//  Created by me on 6/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulAskTellThreadCell.h"
#import "AwfulThread+AwfulMethods.h"

@implementation AwfulAskTellThreadCell

-(void) configureForThread:(AwfulThread *)thread {
    [super configureForThread:thread];
    self.secondTagImage.frame = CGRectMake(self.tagImage.frame.origin.x-1, self.tagImage.frame.origin.y-1, self.secondTagImage.frame.size.width, self.secondTagImage.frame.size.height);
}

-(void) configureTagImage {
    [super configureTagImage];
    NSURL *second_url = [self.thread secondIconURL];
    if(second_url != nil) {
        self.secondTagImage.hidden = NO;
        [self.secondTagImage setImage:[UIImage imageNamed:[second_url lastPathComponent]]];
    }
}

@end
