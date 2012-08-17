//
//  AwfulFYADThreadCell.m
//  Awful
//
//  Created by me on 5/17/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCustomForumFYAD.h"
#import "FVGifAnimation.h"

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
-(void) viewDidLoad {
    [super viewDidLoad];
    
    //change navbar title and formatting
    UILabel *title = [UILabel new];
    title.font = [UIFont fontWithName:@"Zapfino" size:8];
    title.textColor = [UIColor whiteColor];
    title.backgroundColor = [UIColor clearColor];
    title.adjustsFontSizeToFitWidth = YES;
    title.numberOfLines = 2;
    title.textAlignment = UITextAlignmentCenter;
    title.frame = CGRectMake(0, 0, 200, 50);
    title.text = self.forum.name;
    self.navigationItem.titleView = title;
}
-(UIBarButtonItem*) customBackButton {
    //override this method for custom back button
    /*UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:@"get out"
                                                               style:(UIBarButtonItemStyleBordered)
                                                              target:self
                                                              action:@selector(pop)];

    UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"emot-gb2gbs.gif"]
                                                               style:(UIBarButtonItemStyleBordered)
                                                              target:self
                                                              action:@selector(pop)];    */

    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"emot-gb2gbs.gif"]];
    imageView.backgroundColor = [UIColor colorWithRed:1 green:.9 blue:.9 alpha:1];
    imageView.layer.borderWidth = 1;
    imageView.layer.borderColor = [[UIColor blackColor] CGColor];
    imageView.fsH = 30;
    imageView.fsW += 20;
    imageView.contentMode = UIViewContentModeCenter;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(pop)];
    [imageView addGestureRecognizer:tap];
    
    FVGifAnimation *gif = [[FVGifAnimation alloc] initWithURL:
                           [[NSBundle mainBundle] URLForResource:@"emot-gb2gbs" withExtension:@"gif"]
                           ];
    [gif setAnimationToImageView:imageView];

    UIBarButtonItem *barbutton = [[UIBarButtonItem alloc] initWithCustomView:imageView];
    [imageView startAnimating];
    
    return barbutton;
}

-(UIBarButtonItem*) customPostButton {
    //override this method for custom back button
    /*UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithTitle:@"get out"
     style:(UIBarButtonItemStyleBordered)
     target:self
     action:@selector(pop)];
     
     UIBarButtonItem *button = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"emot-gb2gbs.gif"]
     style:(UIBarButtonItemStyleBordered)
     target:self
     action:@selector(pop)];    */
    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"emot-protarget.gif"]];
    imageView.backgroundColor = [UIColor colorWithRed:1 green:.9 blue:.9 alpha:1];
    imageView.layer.borderWidth = 1;
    imageView.layer.borderColor = [[UIColor blackColor] CGColor];
    imageView.fsH = 30;
    imageView.fsW += 20;
    imageView.contentMode = UIViewContentModeCenter;
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(didTapCompose:)];
    [imageView addGestureRecognizer:tap];
    FVGifAnimation *gif = [[FVGifAnimation alloc] initWithURL:
                           [[NSBundle mainBundle] URLForResource:@"emot-protarget" withExtension:@"gif"]
                           ];
    [gif setAnimationToImageView:imageView];
    
    UIBarButtonItem *barbutton = [[UIBarButtonItem alloc] initWithCustomView:imageView];
    [imageView startAnimating];
    
    return barbutton;
}
@end

