//  AwfulLaunchImageViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulLaunchImageViewController.h"

@implementation AwfulLaunchImageViewController

- (void)loadView
{
    UIImageView *imageView = [UIImageView new];
    imageView.contentMode = UIViewContentModeCenter;
    
    // There is seemingly no reliable way to get the launch image (nee Default.png) out of the "asset catalog" (launch images are seemingly just copied over with no archive compilation). I've observed the convention below, but it looks fragile and seems likely to change…
    //
    //   * …between Xcode versions.
    //   * …when changing the minimum iOS version.
    //   * …between the simulator and the device.
    
    // Don't cache launch images (i.e. use +[UIImage imageNamed:]) as we'll probably never use them again.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSURL *portraitURL = [[NSBundle mainBundle] URLForResource:@"LaunchImage-700-Portrait@2x~ipad" withExtension:@"png"];
        UIImage *portrait = [UIImage imageWithContentsOfFile:portraitURL.path];
        NSURL *landscapeURL = [[NSBundle mainBundle] URLForResource:@"LaunchImage-700-Landscape@2x~ipad" withExtension:@"png"];
        UIImage *landscape = [UIImage imageWithContentsOfFile:landscapeURL.path];
        imageView.image = portrait;
        imageView.highlightedImage = landscape;
    } else {
        NSURL *portraitURL;
        if (CGRectGetHeight([UIScreen mainScreen].bounds) >= 568) {
            portraitURL = [[NSBundle mainBundle] URLForResource:@"LaunchImage-700-568h@2x" withExtension:@"png"];
        } else {
            portraitURL = [[NSBundle mainBundle] URLForResource:@"LaunchImage-700@2x" withExtension:@"png"];
        }
        UIImage *portrait = [UIImage imageWithContentsOfFile:portraitURL.path];
        imageView.image = portrait;
    }
    self.view = imageView;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.imageView.highlighted = UIInterfaceOrientationIsLandscape(self.interfaceOrientation);
}

- (UIImageView *)imageView
{
    return (UIImageView *)self.view;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    } else {
        return (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown);
    }
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [UIView transitionWithView:self.imageView
                      duration:duration
                       options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{ self.imageView.highlighted = UIInterfaceOrientationIsLandscape(toInterfaceOrientation); }
                    completion:nil];
}

@end
