//  EmptyViewController.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "EmptyViewController.h"
#import "AwfulFrameworkCategories.h"

@implementation EmptyViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.splitViewController awful_showPrimaryViewController];
}

@end
