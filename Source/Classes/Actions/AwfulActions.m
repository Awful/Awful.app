//
//  AwfulActions.m
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulActions.h"
#import "AwfulAppDelegate.h"

@implementation AwfulActions

@synthesize titles = _titles;
@synthesize viewController = _viewController;

-(id)init
{
    if((self=[super init])) {
        _titles = [[NSMutableArray alloc] init];
    }
    return self;
}

-(NSString *)overallTitle
{
    return @"Actions";
}

- (void)showFromToolbar:(UIToolbar *)toolbar
{
    [self.actionSheet showFromToolbar:toolbar];
}

- (void)showFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated
{
    [self.actionSheet showFromRect:rect inView:view animated:animated];
}

@synthesize actionSheet = _actionSheet;

- (UIActionSheet *)actionSheet
{
    if (_actionSheet)
        return _actionSheet;
    _actionSheet = [[UIActionSheet alloc] initWithTitle:self.overallTitle
                                               delegate:self
                                      cancelButtonTitle:nil
                                 destructiveButtonTitle:nil
                                      otherButtonTitles:nil];
    for (NSString *title in self.titles) {
        [_actionSheet addButtonWithTitle:title];
    }
    [_actionSheet addButtonWithTitle:@"Cancel"];
    _actionSheet.cancelButtonIndex = [self.titles count];
    return _actionSheet;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self actionSheet:nil clickedButtonAtIndex:buttonIndex-1];
}

-(BOOL)isCancelled : (int)index
{
    return index == [self.titles count] || index == -1;
}

@end
