//
//  AwfulPage+ButtonActions.m
//  Awful
//
//  Created by me on 8/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPage.h"
#import "AwfulPage+BarButtons.h"

#import "ButtonSegmentedControl.h"
#import "AwfulPageDataController.h"
#import "AwfulSpecificPageViewController.h"
#import "AwfulThreadReplyComposeController.h"

#import "AwfulRefreshControl.h"
#import "AwfulLoadNextControl.h"

#import "AwfulthreadActions.h"


@implementation AwfulPage (BarButtons)

-(void)updatePagesLabel
{
    self.pagesBarButtonItem.title = [NSString stringWithFormat:@"Page %d of %d", self.currentPage, self.numberOfPages];
    [self.pagesSegmentedControl setEnabled:(self.currentPage < self.numberOfPages) forSegmentAtIndex:1];
    [self.pagesSegmentedControl setEnabled:(self.currentPage > 1) forSegmentAtIndex:0];
}

- (void)updateBookmarked
{
    self.thread.isBookmarkedValue = self.dataController.bookmarked;
}

-(IBAction)segmentedGotTapped : (id)sender
{
    if(sender == self.actionsSegmentedControl) {
        [self tappedActionsSegment:nil];
    } else if(sender == self.pagesSegmentedControl) {
        [self tappedPagesSegment:nil];
    }
}

-(IBAction)tappedPagesSegment:(UISegmentedControl*)segmentedControl
{
    switch (segmentedControl.selectedSegmentIndex) {
        case 0:
            [self prevPage];
            break;
            
        case 1:
            [self nextPage];
            break;
    }
    
    segmentedControl.selectedSegmentIndex = -1;
}

-(IBAction)tappedActionsSegment : (id)sender
{
    if(self.actionsSegmentedControl.selectedSegmentIndex == 0) {
        [self tappedActions:nil];
    } else if(self.actionsSegmentedControl.selectedSegmentIndex == 1) {
        [self tappedCompose:nil];
    }
    self.actionsSegmentedControl.selectedSegmentIndex = -1;
}

-(IBAction)tappedNextPage : (id)sender
{
    [self nextPage];
}

-(void)nextPage
{
    if (self.loadNextPageControl.state != AwfulRefreshControlStateLoading)
        self.loadNextPageControl.state = AwfulRefreshControlStateLoading;
    
    if(self.currentPage < self.numberOfPages) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self loadPageNum:self.currentPage + 1];
    }
}

-(void)prevPage
{
    if(self.currentPage > 1) {
        self.destinationType = AwfulPageDestinationTypeSpecific;
        [self loadPageNum:self.currentPage - 1];
    }
}

-(IBAction)tappedActions:(id)sender
{
    self.actions = [[AwfulThreadActions alloc] initWithThread:self.thread];
    self.actions.viewController = self;
    [self.actions showFromToolbar:self.navigationController.toolbar];
}

-(void)tappedPageNav : (id)sender
{
    if(self.numberOfPages <= 0 || self.currentPage <= 0) {
        return;
    }
    
    UIView *sp_view = self.specificPageController.containerView;
    
    if(self.specificPageController != nil && !self.specificPageController.hiding) {
        
        [self.pagesBarButtonItem setTintColor:[UIColor darkGrayColor]];
        self.specificPageController.hiding = YES;
        [UIView animateWithDuration:0.3
                              delay:0.0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^(void) {
                             sp_view.frame = CGRectOffset(sp_view.frame, 0, sp_view.frame.size.height);
                         }
                         completion:^(BOOL finished) {
                             [sp_view removeFromSuperview];
                             self.specificPageController = nil;
                         }
         ];
        
    } else if(self.specificPageController == nil) {
        
        [self.pagesBarButtonItem setTintColor:[UIColor blackColor]];
        self.specificPageController = [self.storyboard instantiateViewControllerWithIdentifier:@"AwfulSpecificPageController"];
        self.specificPageController.page = self;
        [self.specificPageController loadView];
        sp_view = self.specificPageController.containerView;
        sp_view.frame = CGRectMake(0, self.view.frame.size.height, self.view.frame.size.width, sp_view.frame.size.height);
        
        [self.view addSubview:sp_view];
        [UIView animateWithDuration:0.3 animations:^(void) {
            sp_view.frame = CGRectOffset(sp_view.frame, 0, -sp_view.frame.size.height+40);
        }];
        
        [self.specificPageController.pickerView selectRow:self.currentPage - 1
                                              inComponent:0
                                                 animated:NO];
    }
}

-(void)hidePageNavigation
{
    if(self.specificPageController != nil) {
        [self tappedPageNav:nil];
    }
}

-(IBAction)tappedCompose : (id)sender
{
    AwfulThreadReplyComposeController *composer = [AwfulThreadReplyComposeController new];
    composer.thread = self.thread;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:composer];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentModalViewController:nav animated:YES];
}

@end
