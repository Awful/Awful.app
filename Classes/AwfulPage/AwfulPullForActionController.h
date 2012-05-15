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
    AwfulPullForActionStateLoading
} AwfulPullForActionState;

@protocol AwfulPullForActionDelegate <NSObject>

-(void) didPullHeader;
-(void) didPullFooter;

@end

@protocol AwfulPullForActionViewDelegate <NSObject>

@property (nonatomic) AwfulPullForActionState state;

@end


@interface AwfulPullForActionController : NSObject <UIScrollViewDelegate>
-(id) initWithScrollView:(UIScrollView*)scrollView;
@property (nonatomic,strong) IBOutlet UIScrollView* scrollView;
@property (nonatomic,strong) UIView<AwfulPullForActionViewDelegate>* headerView;
@property (nonatomic,strong) UIView<AwfulPullForActionViewDelegate>* footerView;
@property (nonatomic,strong) UIViewController<AwfulPullForActionDelegate,UIScrollViewDelegate>* delegate;


@end
