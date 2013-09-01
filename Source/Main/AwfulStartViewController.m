//  AwfulStartViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
        self.imageView.image = [UIImage imageNamed:@"Default-Portrait"];
    } else {
        self.imageView.image = [UIImage imageNamed:@"Default-Landscape"];
    }
}

#pragma mark - UIViewController

- (void)loadView
{
    self.view = [[UIImageView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    self.view.backgroundColor = [UIColor darkGrayColor];
    self.view.contentMode = UIViewContentModeBottomRight;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setImageForOrientation:self.interfaceOrientation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else {
        return toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown;
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)orientation
                                         duration:(NSTimeInterval)duration
{
    [self setImageForOrientation:orientation];
}

@end
