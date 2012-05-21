//
//  ButtonSegmentedControl.h
//  Awful
//
//  Created by Sean Berry on 3/27/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulPage;

@interface ButtonSegmentedControl : UISegmentedControl

@property (nonatomic, weak) IBOutlet id<NSObject> target;
@property (nonatomic, assign) SEL action;

@end
