//
//  AwfulStartViewController.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulStartViewController.h"

@interface AwfulStartViewController ()

@property (readonly, weak, nonatomic) UIImageView *imageView;

@end

@implementation AwfulStartViewController

- (UIImageView *)imageView
{
    return (UIImageView *)self.view;
}

- (void)setImageForOrientation:(UIInterfaceOrientation)orientation
{
    if (UIInterfaceOrientationIsPortrait(orientation)) {
        self.imageView.image = [UIImage imageNamed:@"tag-collage-Portrait.png"];
    } else {
        self.imageView.image = [UIImage imageNamed:@"tag-collage-Landscape.png"];
    }
}

#pragma mark - UIViewController

- (void)loadView
{
    self.view = [[UIImageView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    self.view.backgroundColor = [UIColor darkGrayColor];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setImageForOrientation:self.interfaceOrientation];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration
{
    [self setImageForOrientation:orientation];
}

@end
