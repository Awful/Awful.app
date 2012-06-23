//
//  AwfulPullForActionController.h
//  Awful
//
//  Created by me on 5/14/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    AwfulPullForActionStatePulling,
    AwfulPullForActionStateNormal,
    AwfulPullForActionStateLoading,
    //AwfulPullForActionStateRelease
} AwfulPullForActionState;

@class AwfulPullForActionController;

@protocol AwfulPullForActionViewDelegate <NSObject>

@property (nonatomic) AwfulPullForActionState state;
@property (nonatomic,strong) UIActivityIndicatorView* activityView;

@end

@protocol AwfulPullForActionDelegate <NSObject>

@required
-(void) didPullHeader:(UIView<AwfulPullForActionViewDelegate>*)header;
-(void) didPullFooter:(UIView<AwfulPullForActionViewDelegate>*)footer;
-(void) didCancelPullForAction:(AwfulPullForActionController*)pullForActionController;

@end



@interface AwfulPullForActionController : NSObject <UIScrollViewDelegate>
-(id) initWithScrollView:(UIScrollView*)scrollView;
@property (nonatomic,strong) IBOutlet UIScrollView* scrollView;
@property (nonatomic,strong) UIView<AwfulPullForActionViewDelegate>* headerView;
@property (nonatomic,strong) UIView<AwfulPullForActionViewDelegate>* footerView;
@property (nonatomic) AwfulPullForActionState headerState;
@property (nonatomic) AwfulPullForActionState footerState;
@property (nonatomic,strong) UIViewController<AwfulPullForActionDelegate,UIScrollViewDelegate>* delegate;
@property (nonatomic) BOOL userScrolling;


@end
