//
//  AwfulActions.h
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AwfulNavigator;

@interface AwfulActions : NSObject <UIActionSheetDelegate, UIAlertViewDelegate> {
    NSMutableArray *_titles;
    AwfulNavigator *_delegate;
}

@property (nonatomic, retain) NSMutableArray *titles;
@property (nonatomic, assign) AwfulNavigator *delegate;

-(void)show;
-(NSString *)getOverallTitle;
-(BOOL)isCancelled : (int)index;

@end
