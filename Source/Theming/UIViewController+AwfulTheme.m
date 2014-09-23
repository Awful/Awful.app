//  UIViewController+AwfulTheme.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulSettings.h"

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
    return [AwfulTheme currentTheme];
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
    AwfulTheme *theme = self.theme;
    self.tableView.backgroundColor = theme[@"backgroundColor"];
    self.refreshControl.tintColor = theme[@"listTextColor"];
    self.tableView.separatorColor = theme[@"listSeparatorColor"];
    self.tableView.indicatorStyle = theme.scrollIndicatorStyle;
    [self.tableView reloadData];
}

- (AwfulTheme *)theme
{
    return [AwfulTheme currentTheme];
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
    AwfulTheme *theme = self.theme;
    self.collectionView.backgroundColor = theme[@"collectionViewBackgroundColor"];
	self.collectionView.indicatorStyle = theme.scrollIndicatorStyle;
	[self.collectionView reloadData];
}

- (AwfulTheme *)theme
{
    return [AwfulTheme currentTheme];
}

@end
