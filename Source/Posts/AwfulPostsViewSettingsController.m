//
//  AwfulPostsViewSettingsController.m
//  Awful
//
//  Created by Nolan Waite on 2013-03-27.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulPostsViewSettingsController.h"
#import "AwfulSettings.h"

@interface AwfulPostsViewSettingsController ()

@property (weak, nonatomic) UISegmentedControl *darkModeControl;

@end


@implementation AwfulPostsViewSettingsController

#pragma mark - AwfulSemiModalViewController

- (void)presentFromViewController:(UIViewController *)viewController fromView:(UIView *)view
{
    self.coverView.backgroundColor = nil;
    [super presentFromViewController:viewController fromView:view];
}

- (void)userDismiss
{
    [self.delegate userDidDismissPostsViewSettings:self];
    [self dismiss];
}

#pragma mark - UIViewController

- (void)loadView
{
    self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    self.view.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                  UIViewAutoresizingFlexibleTopMargin);
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    
    CGRect inset = CGRectInset(self.view.bounds, 3, 3);
    CGRect fontFrame, darkFrame;
    CGRectDivide(inset, &fontFrame, &darkFrame, CGRectGetWidth(inset) / 2 - 2, CGRectMinXEdge);
    darkFrame.origin.x += CGRectGetWidth(darkFrame) - CGRectGetWidth(fontFrame);
    darkFrame.size.width = CGRectGetWidth(fontFrame);
    
    UIImage *smaller = [UIImage imageNamed:@"font-size-smaller.png"];
    smaller.accessibilityLabel = @"Shrink font size";
    UIImage *larger = [UIImage imageNamed:@"font-size-larger.png"];
    larger.accessibilityLabel = @"Embiggen font size";
    UISegmentedControl *fontSeg = [[UISegmentedControl alloc] initWithItems:@[ smaller, larger ]];
    fontSeg.frame = fontFrame;
    fontSeg.autoresizingMask = (UIViewAutoresizingFlexibleRightMargin |
                                UIViewAutoresizingFlexibleBottomMargin);
    [fontSeg addTarget:self action:@selector(didTapFontSizeSegment:)
      forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:fontSeg];
    
    UISegmentedControl *darkSeg = [[UISegmentedControl alloc] initWithItems:@[ @"Light", @"Dark" ]];
    darkSeg.frame = darkFrame;
    darkSeg.autoresizingMask = (UIViewAutoresizingFlexibleLeftMargin |
                                UIViewAutoresizingFlexibleBottomMargin);
    [darkSeg addTarget:self action:@selector(didTapDarkModeSegment:)
      forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:darkSeg];
    self.darkModeControl = darkSeg;
}

- (void)didTapFontSizeSegment:(UISegmentedControl *)seg
{
    NSDictionary *info = [[AwfulSettings settings] infoForSettingWithKey:@"font_size"];
    NSInteger fontSize = [[AwfulSettings settings].fontSize integerValue];
    if (seg.selectedSegmentIndex == 0) {
        NSNumber *minimum = info[@"Minimum"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && info[@"Minimum~ipad"]) {
            minimum = info[@"Minimum~ipad"];
        }
        if (fontSize > [minimum integerValue]) {
            fontSize -= 1;
        }
    } else if (seg.selectedSegmentIndex == 1) {
        NSNumber *maximum = info[@"Maximum"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && info[@"Maximum~ipad"]) {
            maximum = info[@"Maximum~ipad"];
        }
        if (fontSize < [maximum integerValue]) {
            fontSize += 1;
        }
    }
    [AwfulSettings settings].fontSize = @(fontSize);
    seg.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)didTapDarkModeSegment:(UISegmentedControl *)seg
{
    if (seg.selectedSegmentIndex == 0) {
        [AwfulSettings settings].darkTheme = NO;
    } else if (seg.selectedSegmentIndex == 1) {
        [AwfulSettings settings].darkTheme = YES;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    BOOL darkMode = [AwfulSettings settings].darkTheme;
    self.darkModeControl.selectedSegmentIndex = darkMode ? 1 : 0;
}

@end
