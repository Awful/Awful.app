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

@synthesize titles, delegate;

-(id)init
{
    if((self=[super init])) {
        self.titles = [[NSMutableArray alloc] init];
        self.delegate = nil;
    }
    return self;
}

-(NSString *)getOverallTitle
{
    return @"Actions";
}

-(void)show
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:[self getOverallTitle] delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        for(NSString *title in self.titles) {
            [sheet addButtonWithTitle:title];
        }
        [sheet addButtonWithTitle:@"Cancel"];
        sheet.cancelButtonIndex = [self.titles count];
        
        AwfulNavigator *nav = getNavigator();
        [nav forceShow];
        [sheet showFromToolbar:nav.navigationController.toolbar];
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:[self getOverallTitle] message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
        for(NSString *title in self.titles) {
            [alert addButtonWithTitle:title];
        }
        [alert show];
    }
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
