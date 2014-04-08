//  UIViewController+AwfulTheme.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulPopoverBackgroundView.h"
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
	self.collectionView.indicatorStyle = self.theme.scrollIndicatorStyle;
	[self.collectionView reloadData];
}

- (AwfulTheme *)theme
{
    return [AwfulTheme currentTheme];
}

@end

@implementation AwfulPopoverController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithContentViewController:(UIViewController *)viewController
{
    self = [super initWithContentViewController:viewController];
    if (!self) return nil;
    
    // Overriding -popoverBackgroundViewClass does not seem to work.
    self.popoverBackgroundViewClass = [AwfulPopoverBackgroundView class];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:AwfulSettingsDidChangeNotification object:nil];
    
    return self;
}

- (void)setContentViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    [super setContentViewController:viewController animated:animated];
    [self themeDidChange];
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSString *key = note.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([key isEqual:AwfulSettingsKeys.darkTheme] || [key hasPrefix:@"theme"]) {
        if (self.popoverVisible) {
            [self themeDidChange];
        }
    }
}

- (AwfulTheme *)theme
{
    if ([self.contentViewController respondsToSelector:@selector(theme)]) {
        return ((AwfulViewController *)self.contentViewController).theme;
    } else {
        return [AwfulTheme currentTheme];
    }
}

- (void)themeDidChange
{
    // The API for the popover background view is rather annoying here. Fortunately, we know the class of the view we want. Trek up to just below the window, then flail about for the background view.
    UIViewController *contentViewController = self.contentViewController;
    UIView *probableAncestorOfBackgroundView = contentViewController.view;
    while (probableAncestorOfBackgroundView.superview != probableAncestorOfBackgroundView.window) {
        probableAncestorOfBackgroundView = probableAncestorOfBackgroundView.superview;
    }
    AwfulPopoverBackgroundView *backgroundView = FirstDescendantViewOfClass(probableAncestorOfBackgroundView, self.popoverBackgroundViewClass);
    backgroundView.theme = self.theme;
    [contentViewController themeDidChange];
}

static id FirstDescendantViewOfClass(UIView *root, Class class)
{
    NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count > 0) {
        UIView *view = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([view isKindOfClass:class]) {
            return view;
        }
        [queue addObjectsFromArray:view.subviews];
    }
    return nil;
}

@end
