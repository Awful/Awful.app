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
{
    BOOL _hasAppeared;
}

- (id)init
{
    return [super initWithNibName:nil bundle:nil];
}

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

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (_hasAppeared) {
        // Updates to the table view when it's offscreen don't actually happen. So whenever we're about to appear (after the first time), let's help out by reloading the table.
        [self.tableView reloadData];
    }
    _hasAppeared = YES;
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
