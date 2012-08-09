//
//  AwfulYOSPOSFakeShell.h
//  Awful
//
//  Created by me on 8/9/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AwfulYOSPOSFakeShell : NSObject
-(id) initWithLabel:(UILabel*)label;

-(void) execute;

@property (nonatomic,readonly) NSString* prompt;
@property (nonatomic,readonly) NSString* history;

@property (nonatomic,readwrite) NSString* currentCommand;

@property (nonatomic,readonly,strong) UILabel* label;
@end
