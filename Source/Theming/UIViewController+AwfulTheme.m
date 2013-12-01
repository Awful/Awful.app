//  UIViewController+AwfulTheme.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import <objc/runtime.h>

@implementation UIViewController (AwfulTheme)

- (void)themeDidChange
{
    NSMutableSet *dependants = [NSMutableSet new];
    [dependants addObjectsFromArray:self.childViewControllers];
    if (self.presentedViewController) {
        [dependants addObject:self.presentedViewController];
    }
    if ([self respondsToSelector:@selector(viewControllers)]) {
        NSArray *viewControllers = ((UINavigationController *)self).viewControllers;
        [dependants addObjectsFromArray:viewControllers];
    }
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isViewLoaded = YES"];
    [dependants filterUsingPredicate:predicate];
    [dependants makeObjectsPerformSelector:@selector(themeDidChange)];
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
