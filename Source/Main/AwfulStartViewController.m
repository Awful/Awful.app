//
//  AwfulStartViewController.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
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
    self.view.contentMode = UIViewContentModeTopLeft;
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
