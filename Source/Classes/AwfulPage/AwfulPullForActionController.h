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
@required
@property (nonatomic) AwfulPullForActionState state;
@property (nonatomic,strong) UIActivityIndicatorView* activityView;

@optional
@property (nonatomic, strong) UISwitch* autoF5;
@end

@protocol AwfulPullForActionDelegate <NSObject>

@required
-(void) didPullHeader:(UIView<AwfulPullForActionViewDelegate>*)header;
-(void) didPullFooter:(UIView<AwfulPullForActionViewDelegate>*)footer;
-(void) didCancelPullForAction:(AwfulPullForActionController*)pullForActionController;
@property (readonly) BOOL isOnLastPage;
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
@property (nonatomic,strong) NSTimer* autoRefreshTimer;

@end
