//  AwfulEmptyViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulEmptyViewController.h"

@implementation AwfulEmptyViewController

- (void)themeDidChange
{
    [super themeDidChange];
    self.view.backgroundColor = self.theme[@"backgroundColor"];
}

@end
