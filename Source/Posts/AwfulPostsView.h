//
//  AwfulPostsView.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-29.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol AwfulPostsViewDelegate;


@interface AwfulPostsView : UIView

@property (weak, nonatomic) id <AwfulPostsViewDelegate> delegate;

- (void)reloadData;

@end


@protocol AwfulPostsViewDelegate <NSObject>

@required

- (NSInteger)numberOfPostsInPostsView:(AwfulPostsView *)postsView;

- (NSDictionary *)postsView:(AwfulPostsView *)postsView postAtIndex:(NSInteger)index;

@end