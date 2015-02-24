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

@end

@implementation AwfulTableViewController
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
    
    self.refreshControl.tintColor = theme[@"listTextColor"];
    
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
