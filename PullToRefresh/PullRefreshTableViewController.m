//
//  PullRefreshTableViewController.m
//  Plancast
//
//  Created by Leah Culver on 7/2/10.
//  Copyright (c) 2010 Leah Culver
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import <QuartzCore/QuartzCore.h>
#import "PullRefreshTableViewController.h"

#define REFRESH_HEADER_HEIGHT 52.0f


@implementation PullRefreshTableViewController

@synthesize textPull, textRelease, textLoading, refreshHeaderView, refreshLabel, refreshArrow, refreshSpinner;
@synthesize bottomAllowed, endOfThreadLabel;

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    if (self != nil) {
        textPull = [[NSString alloc] initWithString:@"Pull up to refresh..."];
        textRelease = [[NSString alloc] initWithString:@"Release to refresh..."];
        textLoading = [[NSString alloc] initWithString:@"Loading..."];
        bottomAllowed = NO;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self addPullToRefreshHeader];
}

- (void)addPullToRefreshHeader {
    refreshHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0-REFRESH_HEADER_HEIGHT, 320, REFRESH_HEADER_HEIGHT)];
    refreshHeaderView.backgroundColor = [UIColor clearColor];

    refreshLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 7, 320, REFRESH_HEADER_HEIGHT)];
    refreshLabel.backgroundColor = [UIColor clearColor];
    refreshLabel.font = [UIFont boldSystemFontOfSize:12.0];
    refreshLabel.textAlignment = UITextAlignmentCenter;
    
    endOfThreadLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, -8, 320, REFRESH_HEADER_HEIGHT)];
    endOfThreadLabel.backgroundColor = [UIColor clearColor];
    endOfThreadLabel.font = [UIFont boldSystemFontOfSize:14.0];
    endOfThreadLabel.textAlignment = UITextAlignmentCenter;
    endOfThreadLabel.text = @"End of the thread.";

    refreshArrow = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"grayArrow.png"]];
    refreshArrow.frame = CGRectMake(80, 10, 23.0/2, 30);

    refreshSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    refreshSpinner.frame = CGRectMake(75, 13, 20, 20);
    refreshSpinner.hidesWhenStopped = YES;

    [refreshHeaderView addSubview:refreshLabel];
    [refreshHeaderView addSubview:endOfThreadLabel];
    [refreshHeaderView addSubview:refreshArrow];
    [refreshHeaderView addSubview:refreshSpinner];
    //[self.tableView addSubview:refreshHeaderView];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (isLoading) return;
    isDragging = YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    if(!bottomAllowed) {
        return;
    }
    
    float bottom = scrollView.contentSize.height - scrollView.frame.size.height;
    
    if (isLoading) {
        // Update the content inset, good for section headers
        if (scrollView.contentOffset.y < bottom)
            self.tableView.contentInset = UIEdgeInsetsZero;
        //else if (scrollView.contentOffset.y >= -REFRESH_HEADER_HEIGHT)
         //   self.tableView.contentInset = UIEdgeInsetsMake(-scrollView.contentOffset.y, 0, 0, 0);
    } else if (isDragging && scrollView.contentOffset.y > bottom) {
        // Update the arrow direction and label
        [UIView beginAnimations:nil context:NULL];
        if (scrollView.contentOffset.y > bottom + REFRESH_HEADER_HEIGHT) {
            // User is scrolling above the header
            refreshLabel.text = self.textRelease;
            [refreshArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
        } else { // User is scrolling somewhere within the header
            refreshLabel.text = self.textPull;
            [refreshArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
        }
        [UIView commitAnimations];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (isLoading) return;
    isDragging = NO;
    
    if(!bottomAllowed) {
        return;
    }
    
    float bottom = scrollView.contentSize.height - scrollView.frame.size.height;
    
    if (scrollView.contentOffset.y > bottom + REFRESH_HEADER_HEIGHT) {
        // Released above the header
        [self startLoading];
    }
}

- (void)startLoading {
    isLoading = YES;

    // Show the header
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    self.tableView.contentInset = UIEdgeInsetsMake(0, 0, REFRESH_HEADER_HEIGHT, 0);
    refreshLabel.text = self.textLoading;
    refreshArrow.hidden = YES;
    [refreshSpinner startAnimating];
    [UIView commitAnimations];

    // Refresh action!
    [self refresh];
}

- (void)stopLoading {
    isLoading = NO;

    // Hide the header
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDidStopSelector:@selector(stopLoadingComplete:finished:context:)];
    self.tableView.contentInset = UIEdgeInsetsZero;
    [refreshArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
    [UIView commitAnimations];
}

- (void)stopLoadingComplete:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    // Reset the header
    refreshLabel.text = self.textPull;
    refreshArrow.hidden = NO;
    [refreshSpinner stopAnimating];
}

- (void)dealloc {
    [refreshHeaderView release];
    [refreshLabel release];
    [refreshArrow release];
    [refreshSpinner release];
    [textPull release];
    [textRelease release];
    [textLoading release];
    [super dealloc];
}

@end
