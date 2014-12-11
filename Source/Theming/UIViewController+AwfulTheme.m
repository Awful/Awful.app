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

@interface AwfulViewController ()

@property (assign, nonatomic) BOOL visible;

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

- (void)themeDidChange
{
    [super themeDidChange];
    
    self.view.backgroundColor = self.theme[@"backgroundColor"];
    
    UIScrollView *scrollView;
    if ([self.view isKindOfClass:[UIScrollView class]]) {
        scrollView = (UIScrollView *)self.view;
    } else if ([self.view respondsToSelector:@selector(scrollView)]) {
        scrollView = [(id)self.view scrollView];
    }
    scrollView.indicatorStyle = self.theme.scrollIndicatorStyle;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.visible = YES;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.visible = NO;
}

@end

@interface AwfulTableViewController ()

@property (assign, nonatomic) BOOL visible;

@end

@implementation AwfulTableViewController

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
    
    self.view.backgroundColor = theme[@"backgroundColor"];
    
    self.refreshControl.tintColor = theme[@"listTextColor"];
    
    self.tableView.indicatorStyle = theme.scrollIndicatorStyle;
    self.tableView.separatorColor = theme[@"listSeparatorColor"];
    
    if (self.visible) {
        [self.tableView reloadData];
    }
}

- (AwfulTheme *)theme
{
    return [AwfulTheme currentTheme];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Updates to the table view when it's offscreen are a bad idea, so we'll avoid those and reload just before appearing instead.
    [self.tableView reloadData];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.visible = YES;
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.visible = NO;
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
    
    self.view.backgroundColor = theme[@"collectionViewBackgroundColor"];
    
	self.collectionView.indicatorStyle = theme.scrollIndicatorStyle;
    
	[self.collectionView reloadData];
}

- (AwfulTheme *)theme
{
    return [AwfulTheme currentTheme];
}

@end
