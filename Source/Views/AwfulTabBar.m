//  AwfulTabBar.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulTabBar.h"
#import "CustomBadge.h"

@interface AwfulTabBarSegmentedControl : UISegmentedControl @end


@interface AwfulTabBar ()

@property (weak, nonatomic) AwfulTabBarSegmentedControl *segmentedControl;
@property (nonatomic) NSMutableDictionary *badgeViews;

@end


@implementation AwfulTabBar

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    AwfulTabBarSegmentedControl *segmentedControl = [AwfulTabBarSegmentedControl new];
    segmentedControl.frame = (CGRect){ .size = frame.size };
    [segmentedControl addTarget:self
                         action:@selector(selectTab:)
               forControlEvents:UIControlEventValueChanged];
    segmentedControl.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                         UIViewAutoresizingFlexibleHeight);
    [self addSubview:segmentedControl];
    _segmentedControl = segmentedControl;
    _badgeViews = [NSMutableDictionary new];
    return self;
}

- (void)dealloc
{
    [self stopObservingItems];
}

- (void)setItems:(NSArray *)items
{
    if (_items == items) return;
    [self stopObservingItems];
    [[self.badgeViews allValues] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self.badgeViews removeAllObjects];
    _items = [items copy];
    [self updateSegments];
    self.selectedItem = items[0];
    NSIndexSet *all = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [items count])];
    [items addObserver:self toObjectsAtIndexes:all forKeyPath:@"badgeValue"
               options:NSKeyValueObservingOptionInitial context:&KVOContext];
}

- (void)stopObservingItems
{
    NSIndexSet *all = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_items count])];
    [_items removeObserver:self fromObjectsAtIndexes:all forKeyPath:@"badgeValue"
                   context:&KVOContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context
{
    if (context != &KVOContext) {
        return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
    [self updateBadgeViewForItem:object];
}

static char KVOContext;

- (void)updateBadgeViewForItem:(UITabBarItem *)item
{
    NSUInteger i = [self.items indexOfObject:item];
    if (i == NSNotFound) return;
    [self.badgeViews[@(i)] removeFromSuperview];
    if ([item.badgeValue length] == 0) return;
    CustomBadge *badge = [CustomBadge customBadgeWithString:item.badgeValue];
    badge.userInteractionEnabled = NO;
    [self addSubview:badge];
    self.badgeViews[@(i)] = badge;
    [self setNeedsLayout];
}

- (void)setSelectedItem:(UITabBarItem *)selectedItem
{
    if (_selectedItem == selectedItem) return;
    if (_selectedItem) {
        [self.segmentedControl setImage:MakeNormalImageForSelectedImage(_selectedItem.image)
                      forSegmentAtIndex:[self.items indexOfObject:_selectedItem]];
    }
    _selectedItem = selectedItem;
    self.segmentedControl.selectedSegmentIndex = [self.items indexOfObject:selectedItem];
    [self.segmentedControl setImage:selectedItem.image
                  forSegmentAtIndex:self.segmentedControl.selectedSegmentIndex];
}

- (void)selectTab:(UISegmentedControl *)sender
{
    self.selectedItem = self.items[sender.selectedSegmentIndex];
    if ([self.delegate respondsToSelector:@selector(tabBar:didSelectItem:)]) {
        [self.delegate tabBar:self didSelectItem:self.selectedItem];
    }
}

- (void)updateSegments
{
    [self.segmentedControl removeAllSegments];
    for (NSUInteger i = 0; i < [self.items count]; i++) {
        UITabBarItem *item = self.items[i];
        item.image.accessibilityLabel = item.title;
        UIImage *image = i == 0 ? item.image : MakeNormalImageForSelectedImage(item.image);
        [self.segmentedControl insertSegmentWithImage:image atIndex:i animated:NO];
    }
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    for (NSNumber *i in self.badgeViews) {
        CustomBadge *badge = self.badgeViews[i];
        CGRect frame = badge.frame;
        frame.origin.x = ((CGRectGetWidth(self.frame) / [self.items count]) *
                          ([i integerValue] + 1)) - CGRectGetWidth(frame);
        frame.origin.y = CGRectGetHeight(frame) / -3;
        badge.frame = frame;
    }
}

UIImage * MakeNormalImageForSelectedImage(UIImage *image)
{
    if (!image) return nil;
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, 1, -1);
    CGContextTranslateCTM(context, 0, -image.size.height);
    CGContextSetBlendMode(context, kCGBlendModeMultiply);
    CGContextSetAlpha(context, 0.4);
    CGContextDrawImage(context, (CGRect){ .size = image.size }, image.CGImage);
    UIImage *normal = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    normal.accessibilityLabel = image.accessibilityLabel;
    return normal;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    // 44pt tall hitbox.
    CGRect hitbox = self.bounds;
    CGFloat delta = 44 - CGRectGetHeight(hitbox);
    if (delta > 0) {
        hitbox.origin.y -= delta;
        hitbox.size.height += delta;
    }
    if (CGRectContainsPoint(hitbox, point)) {
        return self.segmentedControl;
    } else {
        return [super hitTest:point withEvent:event];
    }
}

@end


@implementation AwfulTabBarSegmentedControl

#pragma mark - UIView

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // UISegmentedControl doesn't send its action message when tapping the selected segment, even
    // though we want it to.
    NSInteger old = self.selectedSegmentIndex;
    [super touchesBegan:touches withEvent:event];
    if (self.selectedSegmentIndex == old) {
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

#pragma mark - NSObject

+ (void)initialize
{
    if (self != [AwfulTabBarSegmentedControl class]) return;
    AwfulTabBarSegmentedControl *seg = [AwfulTabBarSegmentedControl appearance];
    UIControlState normal = UIControlStateNormal, selected = UIControlStateSelected;
    UIBarMetrics metrics = UIBarMetricsDefault;
    [seg setBackgroundImage:[UIImage imageNamed:@"tabbar"] forState:normal barMetrics:metrics];
    UIImage *selectedBack = [[UIImage imageNamed:@"tabbar-selected"]
                             resizableImageWithCapInsets:UIEdgeInsetsMake(0, 17, 0, 17)];
    [seg setBackgroundImage:selectedBack forState:selected barMetrics:metrics];
    [seg setDividerImage:[UIImage imageNamed:@"tabbar-divider"]
     forLeftSegmentState:normal rightSegmentState:normal
              barMetrics:metrics];

}

@end
