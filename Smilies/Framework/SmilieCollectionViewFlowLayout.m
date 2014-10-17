//  SmilieCollectionViewFlowLayout.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieCollectionViewFlowLayout.h"
#import "SmilieCell.h"

@interface SmilieCollectionViewFlowLayout () <UIGestureRecognizerDelegate>

@property (strong, nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;
@property (strong, nonatomic) UIPanGestureRecognizer *panGestureRecognizer;

@property (strong, nonatomic) NSIndexPath *draggedItemIndexPath;
@property (strong, nonatomic) UIView *dragView;
@property (assign, nonatomic) CGPoint initialDragViewCenter;

@end

@implementation SmilieCollectionViewFlowLayout

#pragma mark - Configuration

- (void)configureCollectionView
{
    for (UIGestureRecognizer *recognizer in self.collectionView.gestureRecognizers) {
        if ([recognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
            [recognizer requireGestureRecognizerToFail:self.longPressGestureRecognizer];
        }
        if ([recognizer isKindOfClass:[UIPanGestureRecognizer class]]) {
            [recognizer requireGestureRecognizerToFail:self.panGestureRecognizer];
        }
    }
    
    [self.collectionView addGestureRecognizer:self.longPressGestureRecognizer];
    [self.collectionView addGestureRecognizer:self.panGestureRecognizer];
}

- (void)setDragReorderingEnabled:(BOOL)dragReorderingEnabled
{
    _dragReorderingEnabled = dragReorderingEnabled;
    _longPressGestureRecognizer.enabled = dragReorderingEnabled;
    _panGestureRecognizer.enabled = dragReorderingEnabled;
}

- (void)setEditing:(BOOL)editing
{
    if (editing != _editing) {
        _editing = editing;
        [self.collectionView.visibleCells setValue:@(editing) forKey:@"editing"];
    }
}

- (void)adjustCellLayoutAttributes:(SmilieCollectionViewFlowLayoutAttributes *)attributes
{
    attributes.editing = self.editing;
    if ([attributes.indexPath isEqual:self.draggedItemIndexPath]) {
        attributes.hidden = YES;
    }
}

#pragma mark - Dragging

- (void)startDraggingCell:(SmilieCell *)cell fromIndexPath:(NSIndexPath *)indexPath
{
    self.draggedItemIndexPath = indexPath;
    
    BOOL wasEditing = cell.editing;
    BOOL wasHighlighted = cell.highlighted;
    CGFloat oldShadowOpacity = cell.layer.shadowOpacity;
    
    cell.highlighted = YES;
    cell.layer.shadowOpacity = 0;
    cell.editing = NO;
    UIView *highlightedSnapshot = [cell snapshotViewAfterScreenUpdates:YES];
    cell.highlighted = NO;
    UIView *normalSnapshot = [cell snapshotViewAfterScreenUpdates:YES];
    
    cell.editing = wasEditing;
    cell.highlighted = wasHighlighted;
    cell.layer.shadowOpacity = oldShadowOpacity;
    
    self.dragView = [[UIView alloc] initWithFrame:cell.bounds];
    self.dragView.layer.shadowOpacity = 0.5;
    self.dragView.layer.shadowOffset = CGSizeZero;
    [self.dragView addSubview:highlightedSnapshot];
    normalSnapshot.frame = highlightedSnapshot.frame;
    [self.dragView addSubview:normalSnapshot];
    self.dragView.center = self.initialDragViewCenter = cell.center;
    [self.collectionView addSubview:self.dragView];
    
    normalSnapshot.alpha = 0;
    [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        highlightedSnapshot.alpha = 0;
        normalSnapshot.alpha = 1;
    } completion:^(BOOL completed) {
        [highlightedSnapshot removeFromSuperview];
    }];
    
    [self invalidateLayout];
}

- (void)moveDraggedItemIfNecessary
{
    NSIndexPath *oldIndexPath = self.draggedItemIndexPath;
    NSIndexPath *newIndexPath = [self.collectionView indexPathForItemAtPoint:self.dragView.center];
    if (!newIndexPath || [newIndexPath isEqual:oldIndexPath]) return;
    
    self.draggedItemIndexPath = newIndexPath;
    
    id<SmilieCollectionViewFlowLayoutDataSource> dataSource = (id<SmilieCollectionViewFlowLayoutDataSource>)self.collectionView.dataSource;
    if ([dataSource respondsToSelector:@selector(collectionView:moveItemAtIndexPath:toIndexPath:)]) {
        [dataSource collectionView:self.collectionView moveItemAtIndexPath:oldIndexPath toIndexPath:newIndexPath];
    }
    
    [self.collectionView performBatchUpdates:^{
        [self.collectionView deleteItemsAtIndexPaths:@[oldIndexPath]];
        [self.collectionView insertItemsAtIndexPaths:@[newIndexPath]];
    } completion:nil];
}

- (void)endDragging
{
    NSIndexPath *indexPath = self.draggedItemIndexPath;
    self.draggedItemIndexPath = nil;
    self.initialDragViewCenter = CGPointZero;
    
    UICollectionViewLayoutAttributes *attributes = [self layoutAttributesForItemAtIndexPath:indexPath];
    [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.dragView.center = attributes.center;
    } completion:^(BOOL finished) {
        [self.dragView removeFromSuperview];
        self.dragView = nil;
        
        [self invalidateLayout];
        
        id<SmilieCollectionViewFlowLayoutDataSource> dataSource = (id<SmilieCollectionViewFlowLayoutDataSource>)self.collectionView.dataSource;
        if ([dataSource respondsToSelector:@selector(collectionView:didFinishDraggingItemToIndexPath:)]) {
            [dataSource collectionView:self.collectionView didFinishDraggingItemToIndexPath:indexPath];
        }
    }];
}

#pragma mark - Internals

- (instancetype)init
{
    if ((self = [super init])) {
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

static void CommonInit(SmilieCollectionViewFlowLayout *self)
{
    [self addObserver:self forKeyPath:@"collectionView" options:NSKeyValueObservingOptionOld context:KVOContext];
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"collectionView" context:KVOContext];
}

static void * KVOContext = &KVOContext;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == KVOContext) {
        UICollectionView *oldCollectionView = change[NSKeyValueChangeOldKey];
        if (![oldCollectionView isEqual:[NSNull null]]) {
            [oldCollectionView removeGestureRecognizer:self.longPressGestureRecognizer];
            [oldCollectionView removeGestureRecognizer:self.panGestureRecognizer];
        }
        [self configureCollectionView];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (UILongPressGestureRecognizer *)longPressGestureRecognizer
{
    if (!_longPressGestureRecognizer) {
        _longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(didLongPress:)];
        _longPressGestureRecognizer.delegate = self;
        _longPressGestureRecognizer.enabled = self.dragReorderingEnabled;
        _longPressGestureRecognizer.minimumPressDuration = 0.8;
    }
    return _longPressGestureRecognizer;
}

- (UIPanGestureRecognizer *)panGestureRecognizer
{
    if (!_panGestureRecognizer) {
        _panGestureRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(didPan:)];
        _panGestureRecognizer.delegate = self;
        _panGestureRecognizer.enabled = self.dragReorderingEnabled;
    }
    return _panGestureRecognizer;
}

- (void)didLongPress:(UILongPressGestureRecognizer *)sender
{
    switch (sender.state) {
        case UIGestureRecognizerStateBegan: {
            CGPoint pressedPoint = [sender locationInView:self.collectionView];
            NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:pressedPoint];
            if (!indexPath) break;
            SmilieCell *cell = (SmilieCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
            if (!cell) break;
            
            if ([cell isKindOfClass:[SmilieCell class]]) {
                if (cell.editing) {
                    UIView *removeControl = cell.removeControl;
                    const UIEdgeInsets insets = (UIEdgeInsets){.top = -6, .bottom = -6, .left = -6, .right = -6};
                    CGRect removeHitBounds = UIEdgeInsetsInsetRect(removeControl.bounds, insets);
                    if (CGRectContainsPoint(removeHitBounds, [sender locationInView:removeControl])) {
                        id<SmilieCollectionViewFlowLayoutDataSource> dataSource = (id<SmilieCollectionViewFlowLayoutDataSource>)self.collectionView.dataSource;
                        if ([dataSource respondsToSelector:@selector(collectionView:deleteItemAtIndexPath:)]) {
                            [dataSource collectionView:self.collectionView deleteItemAtIndexPath:indexPath];
                        }
                        break;
                    }
                }
            }
            
            if (!self.editing) {
                self.editing = YES;
                id delegate = self.collectionView.dataSource;
                if ([delegate respondsToSelector:@selector(collectionView:didStartEditingItemAtIndexPath:)]) {
                    [delegate collectionView:self.collectionView didStartEditingItemAtIndexPath:indexPath];
                }
            }
            
            [self startDraggingCell:cell fromIndexPath:indexPath];
            break;
        }
            
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateEnded:
            if (self.draggedItemIndexPath) {
                [self endDragging];
            }
            break;
            
        default: break;
    }
}

- (void)didPan:(UIPanGestureRecognizer *)sender
{
    switch (sender.state) {
        case UIGestureRecognizerStateChanged: {
            CGPoint translation = [sender translationInView:self.collectionView];
            self.dragView.center = CGPointMake(self.initialDragViewCenter.x + translation.x, self.initialDragViewCenter.y + translation.y);
            [self moveDraggedItemIfNecessary];
            break;
        }
            
        default: break;
    }
}

#pragma mark - UICollectionViewLayout

+ (Class)layoutAttributesClass
{
    return [SmilieCollectionViewFlowLayoutAttributes class];
}

- (NSArray *)layoutAttributesForElementsInRect:(CGRect)rect
{
    NSArray *layoutAttributes = [super layoutAttributesForElementsInRect:rect];
    for (SmilieCollectionViewFlowLayoutAttributes *attributes in layoutAttributes) {
        if (attributes.representedElementCategory == UICollectionElementCategoryCell) {
            [self adjustCellLayoutAttributes:attributes];
        }
    }
    return layoutAttributes;
}

- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SmilieCollectionViewFlowLayoutAttributes *attributes = (SmilieCollectionViewFlowLayoutAttributes *)[super layoutAttributesForItemAtIndexPath:indexPath];
    [self adjustCellLayoutAttributes:attributes];
    return attributes;
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if ([gestureRecognizer isEqual:self.panGestureRecognizer]) {
        return self.draggedItemIndexPath != nil;
    }
    
    if ([gestureRecognizer isEqual:self.longPressGestureRecognizer]) {
        return self.draggedItemIndexPath == nil;
    }
    
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ([gestureRecognizer isEqual:self.longPressGestureRecognizer]) {
        return [otherGestureRecognizer isEqual:self.panGestureRecognizer];
    } else if ([gestureRecognizer isEqual:self.panGestureRecognizer]) {
        return [otherGestureRecognizer isEqual:self.longPressGestureRecognizer];
    } else {
        return NO;
    }
}

@end

@implementation SmilieCollectionViewFlowLayoutAttributes

- (id)copyWithZone:(NSZone *)zone
{
    SmilieCollectionViewFlowLayoutAttributes *attributes = [super copyWithZone:zone];
    attributes->_editing = _editing;
    return attributes;
}

- (BOOL)isEqual:(id)object
{
    if (![object isKindOfClass:[SmilieCollectionViewFlowLayoutAttributes class]]) return NO;
    
    SmilieCollectionViewFlowLayoutAttributes *other = object;
    if (![super isEqual:other]) {
        return NO;
    }
    
    if (_editing != other->_editing) {
        return NO;
    }
    
    return YES;
}

- (NSUInteger)hash
{
    return [super hash] + _editing;
}

@end
