//
//  AwfulActions.m
//  Awful
//
//  Created by Regular Berry on 6/23/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulActions.h"
#import "AwfulNavigator.h"
#import "AwfulAppDelegate.h"

@implementation AwfulActions

@synthesize titles = _titles;
@synthesize delegate = _delegate;

-(id)init
{
    _titles = [[NSMutableArray alloc] init];
    _delegate = nil;
    return self;
}

-(void)dealloc
{
    [_titles release];
    [super dealloc];
}

-(NSString *)getOverallTitle
{
    return @"Actions";
}

-(void)show
{
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[self getOverallTitle] delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    for(NSString *title in self.titles) {
        [sheet addButtonWithTitle:title];
    }
    [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = [self.titles count];
    
    AwfulNavigator *nav = getNavigator();
    [nav forceShow];
    [sheet showFromToolbar:nav.navigationController.toolbar];
    [sheet release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
}

-(BOOL)isCancelled : (int)index
{
    return index == [self.titles count];
}

@end
