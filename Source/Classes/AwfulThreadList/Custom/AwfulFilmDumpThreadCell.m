//
//  AwfulFilmDumpThreadCell.m
//  Awful
//
//  Created by me on 6/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFilmDumpThreadCell.h"
#import "AwfulThread+AwfulMethods.h"

@implementation AwfulFilmDumpThreadCell

-(void) configureForThread:(AwfulThread *)thread {
    [super configureForThread:thread];
    self.ratingImage.hidden = YES;
}

-(void)configureTagImage {
    self.secondTagImage.hidden = YES;
    
    double rating = self.thread.threadRating.doubleValue;
    NSString *image;
    
    if (rating == 0)
        image = @"0.0stars.png";
    
    else if (rating < 1.25)
        image = @"1.0stars.png";
    
    else if (rating < 1.75)
        image = @"1.0stars.png";
    
    else if (rating < 2.25)
        image = @"2.0stars.png";
    
    else if (rating < 2.75)
        image = @"2.5stars.png";
    
    else if (rating < 3.25)
        image = @"3.0stars.png";
    
    else if (rating < 3.75)
        image = @"3.5stars.png";
    
    else if (rating < 4.25)
        image = @"4.0stars.png";
    
    else if (rating < 4.75)
        image = @"4.5stars.png";

    else
        image = @"5.0stars.png";
        
    self.tagImage.image = [UIImage imageNamed:image];
}
@end
