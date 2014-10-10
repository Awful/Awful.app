//  SmilieFavoriteToggler.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieFavoriteToggler.h"
#import "Smilie.h"
#import "SmilieMetadata.h"

@interface SmilieFavoriteToggler () <UIPopoverPresentationControllerDelegate>

@property (readonly, strong, nonatomic) UIButton *button;
@property (strong, nonatomic) Smilie *smilie;
@property (weak, nonatomic) UIView *targetView;

@end

@implementation SmilieFavoriteToggler

- (instancetype)initWithSmilie:(Smilie *)smilie pointingAtView:(UIView *)targetView
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _smilie = smilie;
        _targetView = targetView;
        
        self.modalPresentationStyle = UIModalPresentationPopover;
        UIPopoverPresentationController *popover = self.popoverPresentationController;
        popover.delegate = self;
        popover.backgroundColor = [UIColor blackColor];
        popover.sourceRect = targetView.bounds;
        popover.sourceView = targetView;
        
        self.preferredContentSize = CGSizeMake(62, 23);
    }
    return self;
}

- (UIButton *)button
{
    return (UIButton *)self.view;
}

- (void)loadView
{
    self.view = [UIButton new];
    self.view.backgroundColor = [UIColor blackColor];
    self.view.tintColor = [UIColor whiteColor];
    self.button.titleLabel.font = [UIFont systemFontOfSize:11];
    self.button.showsTouchWhenHighlighted = YES;
    [self.button addTarget:self action:@selector(didTapButton) forControlEvents:UIControlEventTouchUpInside];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.button setTitle:(self.smilie.metadata.isFavorite ? @"Unfavorite" : @"Favorite") forState:UIControlStateNormal];
}

- (void)didTapButton
{
    [self dismissViewControllerAnimated:NO completion:nil];
    self.smilie.metadata.isFavorite = !self.smilie.metadata.isFavorite;
    NSError *error;
    if (![self.smilie.managedObjectContext save:&error]) {
        NSLog(@"%s error saving: %@", __PRETTY_FUNCTION__, error);
    }
}

#pragma mark - UIAdaptivePresentationControllerDelegate

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller
{
    return UIModalPresentationNone;
}

#pragma mark - UIPopoverPresentationControllerDelegate

- (void)popoverPresentationController:(UIPopoverPresentationController *)popoverPresentationController willRepositionPopoverToRect:(inout CGRect *)rect inView:(inout UIView **)view
{
    *rect = self.targetView.bounds;
    *view = self.targetView;
}

@end
