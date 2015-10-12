//  AwfulViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulViewController.h"
#import "Awful-Swift.h"

@implementation UIViewController (ThemeSupport)

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

static void CommonInit(UIViewController *self)
{
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
}

@interface AwfulViewController ()

@property (assign, nonatomic) BOOL visible;

@end

@implementation AwfulViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        CommonInit(self);
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        CommonInit(self);
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self themeDidChange];
}

- (Theme *)theme
{
    return [Theme currentTheme];
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

@property (nonatomic) InfiniteTableController *infiniteScrollController;

@end

@implementation AwfulTableViewController
{
    BOOL _viewIsLoading;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        CommonInit(self);
    }
    return self;
}

- (instancetype)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithStyle:style])) {
        CommonInit(self);
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        CommonInit(self);
    }
    return self;
}

- (void)setPullToRefreshBlock:(void (^)(void))pullToRefreshBlock
{
    _pullToRefreshBlock = [pullToRefreshBlock copy];
    
    if (pullToRefreshBlock) {
        ConfigureRefreshControl(self);
    } else {
        self.refreshControl = nil;
    }
}

- (void)setScrollToLoadMoreBlock:(void (^)(void))scrollToLoadMoreBlock
{
    _scrollToLoadMoreBlock = [scrollToLoadMoreBlock copy];
    
    if (scrollToLoadMoreBlock) {
        ConfigureInfiniteScroll(self);
    } else {
        self.infiniteScrollController = nil;
    }
}

- (void)viewDidLoad
{
    _viewIsLoading = YES;
    
    [super viewDidLoad];
    
    if (self.pullToRefreshBlock) {
        ConfigureRefreshControl(self);
    }
    
    if (self.scrollToLoadMoreBlock) {
        ConfigureInfiniteScroll(self);
    }
    
    [self themeDidChange];
    
    _viewIsLoading = NO;
}

- (void)themeDidChange
{
    [super themeDidChange];
    Theme *theme = self.theme;
    
    self.view.backgroundColor = theme[@"backgroundColor"];
    
    self.refreshControl.tintColor = theme[@"listTextColor"];
    self.infiniteScrollController.spinnerColor = theme[@"listTextColor"];
    
    self.tableView.indicatorStyle = theme.scrollIndicatorStyle;
    self.tableView.separatorColor = theme[@"listSeparatorColor"];
    
    if (!_viewIsLoading) {
        [self.tableView reloadData];
    }
}

- (Theme *)theme
{
    return [Theme currentTheme];
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

static void ConfigureRefreshControl(AwfulTableViewController *self)
{
    if (!self.refreshControl) {
        self.refreshControl = [UIRefreshControl new];
        [self.refreshControl addTarget:self action:@selector(_didPullToRefresh) forControlEvents:UIControlEventValueChanged];
    }
}

- (void)_didPullToRefresh
{
    self.pullToRefreshBlock();
}

static void ConfigureInfiniteScroll(AwfulTableViewController *self)
{
    self.infiniteScrollController = [[InfiniteTableController alloc] initWithTableView:self.tableView loadMore:self.scrollToLoadMoreBlock];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.infiniteScrollController scrollViewDidScroll:scrollView];
}

@end

@implementation AwfulCollectionViewController
{
    BOOL _viewIsLoading;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        CommonInit(self);
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
    if ((self = [super initWithCoder:coder])) {
        CommonInit(self);
    }
    return self;
}

- (void)viewDidLoad
{
    _viewIsLoading = YES;
    [super viewDidLoad];
    [self themeDidChange];
    _viewIsLoading = NO;
}

- (void)themeDidChange
{
    [super themeDidChange];
    Theme *theme = self.theme;
    
    self.view.backgroundColor = theme[@"backgroundColor"];
    
    self.collectionView.indicatorStyle = theme.scrollIndicatorStyle;
    
    if (!_viewIsLoading) {
        [self.collectionView reloadData];
    }
}

- (Theme *)theme
{
    return [Theme currentTheme];
}

@end
