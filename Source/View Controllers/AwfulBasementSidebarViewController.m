//  AwfulBasementSidebarViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBasementSidebarViewController.h"
#import "AwfulUIKitAndFoundationCategories.h"

@implementation AwfulBasementSidebarViewController

- (void)dealloc
{
    [self stopObservingItems];
}

- (id)initWithStyle:(UITableViewStyle)style
{
    return [super initWithStyle:UITableViewStylePlain];
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:CellIdentifier];
    
    // Leaving `scrollsToTop` set to its default `YES` prevents the basement's main content view from ever scrolling to top when someone taps the status bar. (If multiple scroll views can scroll to top, none of them actually will.) We set it to `NO` so main content views work as expected. Any sidebar with enough items to make scrolling to top a valuable behaviour is probably ill-conceived anyway, so this is a reasonable setting.
    self.tableView.scrollsToTop = NO;
}

static NSString * const CellIdentifier = @"Cell";

- (void)themeDidChange
{
    [super themeDidChange];
    self.view.backgroundColor = self.theme[@"basementBackgroundColor"];
    [self.tableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self.tableView awful_hideExtraneousSeparators];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self selectRowForSelectedItem];
    
    // Normally on first appear this table's rows are inserted with an animation. This disables that animation.
    [UIView setAnimationsEnabled:NO];
    [self.tableView beginUpdates];
    [self.tableView endUpdates];
    [UIView setAnimationsEnabled:YES];
}

- (void)setItems:(NSArray *)items
{
    if (_items == items) return;
    [self stopObservingItems];
    _items = [items copy];
    if (![_items containsObject:self.selectedItem]) {
        self.selectedItem = _items[0];
    }
    [self.tableView reloadData];
    [_items addObserver:self
     toObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _items.count)]
             forKeyPath:@"badgeValue"
                options:0
                context:KVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context != KVOContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    if ([keyPath isEqualToString:@"badgeValue"]) {
        UITabBarItem *tabBarItem = object;
        NSUInteger i = [self.items indexOfObject:tabBarItem];
        [self.tableView reloadRowsAtIndexPaths:@[ [NSIndexPath indexPathForRow:i inSection:0] ]
                              withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (void)stopObservingItems
{
    [_items removeObserver:self
      fromObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, _items.count)]
                forKeyPath:@"badgeValue"
                   context:KVOContext];
}

static void * KVOContext = &KVOContext;

- (void)setSelectedItem:(UITabBarItem *)selectedItem
{
    if (_selectedItem == selectedItem) return;
    _selectedItem = selectedItem;
    if ([self isViewLoaded]) {
        [self selectRowForSelectedItem];
    }
}

- (void)selectRowForSelectedItem
{
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[self.items indexOfObject:self.selectedItem]
                                                inSection:0];
    [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
}

#pragma mark UITableViewDataSource and UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    UITabBarItem *item = self.items[indexPath.row];
    cell.imageView.contentMode = UIViewContentModeCenter;
    cell.imageView.image = item.image;
    cell.textLabel.text = item.title;
    cell.textLabel.textColor = self.theme[@"basementLabelColor"];
    if (item.badgeValue.length > 0) {
        UILabel *badge = (UILabel *)cell.accessoryView ?: [UILabel new];
        badge.textColor = self.theme[@"basementBadgeColor"];
        badge.text = item.badgeValue;
        [badge sizeToFit];
        cell.accessoryView = badge;
    } else {
        cell.accessoryView = nil;
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor clearColor];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITabBarItem *item = self.items[indexPath.row];
    [self.delegate sidebar:self didSelectItem:item];
}

@end
