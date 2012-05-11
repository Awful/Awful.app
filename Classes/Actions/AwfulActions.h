//
//  AwfulActions.h
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulActions : NSObject <UIActionSheetDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) NSMutableArray *titles;
@property (nonatomic, weak) UIViewController *viewController;
@property (readonly, strong, nonatomic) UIActionSheet *actionSheet;
@property (readonly, nonatomic) NSString *overallTitle;

- (void)showFromToolbar:(UIToolbar *)toolbar;
- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated;

- (BOOL)isCancelled : (int)index;

@end
