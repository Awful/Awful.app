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
    self.imageView.highlighted = CGRectGetWidth(self.view.bounds) == self.imageView.highlightedImage.size.width;
}

- (UIImageView *)imageView
{
    return (UIImageView *)self.view;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if (self.traitCollection.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        return UIInterfaceOrientationMaskAll;
    } else {
        return (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown);
    }
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id <UIViewControllerTransitionCoordinatorContext> context) {
        self.imageView.highlighted = size.width == self.imageView.highlightedImage.size.width;
    } completion:nil];
}

@end
