//
//  AwfulYOSPOSFakeShell.m
//  Awful
//
//  Created by me on 8/9/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulYOSPOSFakeShell.h"
#import "AwfulUser+AwfulMethods.h"
#import "AwfulYOSPOSHTTPRequestOperation.h"
#import "YosposhCommand.h"

@implementation AwfulYOSPOSFakeShell
@synthesize history = _history;
@synthesize currentCommand = _currentCommand;
@synthesize tty = _tty;

-(id) initWithTextView:(UITextView*)textView {
    self = [super init];
    _tty = textView;
    _tty.delegate = self;
    _history = [NSMutableString new];
    [self update];
    self.isExecuting = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(gotHTTPResponseCode:)
                                                 name:@"awful"
                                               object:nil
     ];
    
    return self;
}

-(NSString*) prompt {
    NSMutableString *name = [[[AwfulUser currentUser] userName] mutableCopy];
    [name replaceOccurrencesOfString:@"d" withString:@"\\ " options:(0) range:NSMakeRange(0, name.length)];
    
    return [NSString stringWithFormat:@"yospos:~ %@$", [[AwfulUser currentUser] userName]];
}

-(void) update {
    currentCommandPosition = self.history.length + self.prompt.length + 1;
    
    self.tty.text = self.history;
    if (!self.isExecuting)
        self.tty.text = [self.history stringByAppendingFormat:@"%@ %@", self.prompt, self.currentCommand];
}

-(void) setCurrentCommand:(NSString *)currentCommand {
    _currentCommand = currentCommand;
    [self performSelectorOnMainThread:@selector(update) withObject:nil waitUntilDone:NO];
}

-(void) execute {
    self.isExecuting = YES;
    [self.history appendFormat:@"%@ %@\n", self.prompt, self.currentCommand];
    [self update];
    
    NSString* forkbomb = @":(){ :|:& };:";
    if ([self.currentCommand isEqualToString:forkbomb]) {
        [self runCommand:[NSArray arrayWithObject:@"forkbomb"]];
        return;
    }
    
    NSArray *args = [self.currentCommand componentsSeparatedByString:@" "];
    
    [self runCommand:args];
    _currentCommand = @"";
    
}

-(void) runCommand:(NSArray*)commands {
    NSString *className = [NSString stringWithFormat:@"YosposhCommand_%@", [commands objectAtIndex:0]];
    Class yosposhCommand = NSClassFromString(className);
    
    if (yosposhCommand == nil) {
        [self outputLine:@"-yosposh: %@: command not found", [commands objectAtIndex:0]];
        self.isExecuting = NO;
    }
    else {
        _executingCommand = [[yosposhCommand alloc] initWithArgs:commands shell:self];
    }
}


-(void) output:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    NSString *s = [NSString stringWithFormat:format, args];
    va_end(args);

    [self.history appendString:s];
    [self performSelectorOnMainThread:@selector(update) withObject:nil waitUntilDone:NO];
}


-(void) outputLine:(NSString*)format, ... {
    va_list args;
    va_start(args, format);
    NSString *s = [NSString stringWithFormat:[format stringByAppendingString:@"\n"], args];
    va_end(args);
    
    [self.history appendString:s];
    [self performSelectorOnMainThread:@selector(update) withObject:nil waitUntilDone:NO];
}

-(void) setIsExecuting:(BOOL)isExecuting {
    _isExecuting = isExecuting;
    
    self.tty.userInteractionEnabled = YES;
    self.tty.scrollEnabled = YES;
    
    if (!isExecuting) {
        self.currentCommand = @"";
    }
        
}

-(BOOL) textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if (self.isExecuting) return NO;
    
    if ([text isEqualToString:@"\n"]) {
        self.currentCommand = [textView.text substringFromIndex:currentCommandPosition];
        [self execute];
        return NO;
    }
    
    //don't let user backspace past the prompt
    if (range.location < currentCommandPosition)
        return NO;
    
    
    return YES;
}

@end
