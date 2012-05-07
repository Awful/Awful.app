//
//  AwfulPostComposerView.m
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPostComposerView.h"

@implementation AwfulPostComposerView

- (void) awakeFromNib
{
    [super awakeFromNib];
        
        NSBundle *bundle = [NSBundle mainBundle];
        NSURL *indexFileURL = [bundle URLForResource:@"editor" withExtension:@"html"];
        [self loadRequest:[NSURLRequest requestWithURL:indexFileURL]];
        
    
}

-(void) bold {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand(\"Bold\")"];
}

-(void) italic {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand(\"Italic\")"];
}

-(void) underline {
    [self stringByEvaluatingJavaScriptFromString:@"document.execCommand(\"Underline\")"];
}
@end
