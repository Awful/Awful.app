//
//  AwfulFilmDumpThreadCell.m
//  Awful
//
//  Created by me on 6/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCustomForumFilmDump.h"
#import "AwfulThread+AwfulMethods.h"

@implementation AwfulFilmDumpThreadCell
//this cell removes the thread tag and replaces it with the rating

-(void) configureForThread:(AwfulThread *)thread {
    [super configureForThread:thread];
    self.ratingImage.hidden = YES;
    self.detailTextLabel.text = nil;
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
        
    CGImageRef ref = [[UIImage imageNamed:image] CGImage];
    UIImage *stars = [UIImage imageWithCGImage:ref scale:2 orientation:(UIImageOrientationUp)];
    
    
    self.imageView.image = stars;
}

+(UIFont*) textLabelFont { return [UIFont boldSystemFontOfSize:18]; }
@end
