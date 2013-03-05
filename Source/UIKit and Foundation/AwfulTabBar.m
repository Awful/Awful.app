//
//  AwfulTabBar.m
//  Awful
//
//  Created by Nolan Waite on 2012-12-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTabBar.h"
#import "CustomBadge.h"

@interface AwfulSegmentedControl : UISegmentedControl @end


@interface AwfulTabBar ()

@property (weak, nonatomic) AwfulSegmentedControl *segmentedControl;

@property (nonatomic) NSMutableDictionary *badgeViews;

@end


@implementation AwfulTabBar

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    AwfulSegmentedControl *segmentedControl = [AwfulSegmentedControl new];
    segmentedControl.frame = (CGRect){ .size = frame.size };
    [segmentedControl addTarget:self
                         action:@selector(selectTab:)
               forControlEvents:UIControlEventValueChanged];
    segmentedControl.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                         UIViewAutoresizingFlexibleHeight);
    UIImage *back = [[UIImage imageNamed:@"tab-background.png"]
                     resizableImageWithCapInsets:UIEdgeInsetsZero];
    [segmentedControl setBackgroundImage:back
                                forState:UIControlStateNormal
                              barMetrics:UIBarMetricsDefault];
    UIImage *selected = [[UIImage imageNamed:@"tab-selected.png"]
                         resizableImageWithCapInsets:UIEdgeInsetsMake(0, 4, 0, 4)];
    [segmentedControl setBackgroundImage:selected
                                forState:UIControlStateSelected
                              barMetrics:UIBarMetricsDefault];
    [segmentedControl setDividerImage:[UIImage imageNamed:@"tab-divider.png"]
                  forLeftSegmentState:UIControlStateNormal
                    rightSegmentState:UIControlStateNormal
                           barMetrics:UIBarMetricsDefault];
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

@end


@implementation AwfulSegmentedControl

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    NSInteger old = self.selectedSegmentIndex;
    [super touchesBegan:touches withEvent:event];
    if (self.selectedSegmentIndex == old) {
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

@end
