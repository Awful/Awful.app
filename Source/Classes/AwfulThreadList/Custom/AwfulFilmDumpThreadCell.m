//
//  AwfulFilmDumpThreadCell.m
//  Awful
//
//  Created by me on 6/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFilmDumpThreadCell.h"

@implementation AwfulFilmDumpThreadCell

-(void)configureTagImage {
    //NSLog(@"rating:%i",thread.threadRatingValue);
    self.tagImage.image = [UIImage imageNamed:@"1.5stars.png"];
}
@end
