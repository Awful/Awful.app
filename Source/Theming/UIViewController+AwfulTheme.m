//  UIViewController+AwfulTheme.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import <objc/runtime.h>

@implementation UIViewController (AwfulTheme)

- (void)themeDidChange
{
	if (self.isViewLoaded) {
		self.view.backgroundColor = AwfulTheme.currentTheme[@"backgroundColor"];
	}
	
	for (UIViewController *child in self.childViewControllers) {
		if ([child isViewLoaded]) {
			[child themeDidChange];
		}
	}
	UIViewController *presented = self.presentedViewController;
	if (presented) {
		if ([presented isViewLoaded]) {
			[presented themeDidChange];
		}
	}
}

@end

@implementation AwfulViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self themeDidChange];
}

@end

@implementation AwfulTableViewController

-(void)themeDidChange
{
	[super themeDidChange];
	
	for (UITableViewCell *cell in self.tableView.visibleCells) {
		[self themeCell:cell atIndexPath:[self.tableView indexPathForCell:cell]];
	}
}

-(void)themeCell:(UITableViewCell *)cell atIndexPath:indexPath
{
	
}

@end

@implementation AwfulCollectionViewController

-(void)themeDidChange
{
	[super themeDidChange];
	
	for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
		[self themeCell:cell atIndexPath:[self.collectionView indexPathForCell:cell]];
	}
}

-(void)themeCell:(UITableViewCell *)cell atIndexPath:indexPath
{
	
}

@end

@implementation AwfulThemedNavigationController

@end
