//
//  AwfulYOSPOSFakeShell.h
//  Awful
//
//  Created by me on 8/9/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class YosposhCommand;

@interface AwfulYOSPOSFakeShell : NSObject <UITextViewDelegate> {
    int currentCommandPosition;
}
-(id) initWithTextView:(UITextView*)textView;

-(void) execute;

@property (nonatomic,readonly) NSString* prompt;
@property (nonatomic,readonly) NSMutableString* history;
@property (nonatomic,strong) YosposhCommand* executingCommand;

-(void) output:(NSString*)format, ...;
-(void) outputLine:(NSString*)format, ... ;

@property (nonatomic,readwrite) NSString* currentCommand;

@property (nonatomic,readonly,strong) UITextView* tty;
@property (nonatomic) BOOL isExecuting;
@end
