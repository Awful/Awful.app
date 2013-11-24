//  UIViewController+AwfulTheme.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import <objc/runtime.h>

@implementation UIViewController (AwfulTheme)

- (void)themeDidChange
{
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

- (AwfulTheme *)theme
{
    return AwfulTheme.currentTheme;
}

@end

@implementation AwfulTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self themeDidChange];
}

- (void)themeDidChange
{
	[super themeDidChange];
	self.tableView.backgroundColor = self.theme[@"backgroundColor"];
	self.refreshControl.tintColor = self.theme[@"listTextColor"];
	self.tableView.indicatorStyle = self.theme.scrollIndicatorStyle;
	for (UITableViewCell *cell in self.tableView.visibleCells) {
		[self themeCell:cell atIndexPath:[self.tableView indexPathForCell:cell]];
	}
}

-(void)themeCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
	
}

- (AwfulTheme *)theme
{
    return AwfulTheme.currentTheme;
}

@end

@implementation AwfulCollectionViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self themeDidChange];
}

- (void)themeDidChange
{
	[super themeDidChange];
	self.collectionView.indicatorStyle = self.theme.scrollIndicatorStyle;
	for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
		[self themeCell:cell atIndexPath:[self.collectionView indexPathForCell:cell]];
	}
}

- (void)themeCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
	
}

- (AwfulTheme *)theme
{
    return AwfulTheme.currentTheme;
}

@end
