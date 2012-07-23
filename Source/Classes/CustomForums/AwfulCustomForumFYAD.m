//
//  AwfulFYADThreadCell.m
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCustomForumFYAD.h"

@implementation AwfulFYADThreadCell


-(void)configureForThread:(AwfulThread *)thread {
    [super configureForThread:thread];

    self.badgeColor = [UIColor purpleColor];
}

//set custom fonts and colors
+(UIColor*) textColor { return [UIColor blackColor]; }
+(UIColor*) backgroundColor { return  [UIColor colorWithRed:1 green:.8 blue:1 alpha:1]; }
+(UIFont*) textLabelFont { return [UIFont fontWithName:@"MarkerFelt-Wide" size:18]; }
+(UIFont*) detailLabelFont { return [UIFont fontWithName:@"Marker Felt" size:12]; }

@end

@implementation AwfulFYADThreadListController

-(UIBarButtonItem*) customBackButton {
    //override this method for custom back button
    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:@"get out"
                                                               style:(UIBarButtonItemStyleBordered)
                                                              target:self
                                                              action:@selector(pop)];
    return button;
}
@end

