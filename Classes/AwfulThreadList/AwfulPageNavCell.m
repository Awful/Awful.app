//
//  AwfulPageNavCell.m
//  Awful
//
//  Created by Sean Berry on 2/2/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageNavCell.h"
#import "AwfulPageCount.h"

@implementation AwfulPageNavCell

@synthesize nextButton, prevButton, pageLabel;

-(void)configureForPageCount : (AwfulPageCount *)pages thread_count : (int)count
{
    self.pageLabel.text = [NSString stringWithFormat:@"Page %d", pages.currentPage];
    
    [self.prevButton removeFromSuperview];
    if(pages.currentPage > 1) {
        [self addSubview:self.prevButton];
    }
    
    [self addSubview:self.nextButton];
}

@end