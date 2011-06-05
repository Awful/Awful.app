//
//  ForumsList.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulForum.h"


@interface ForumsList : UITableViewController <UIAlertViewDelegate> {
    NSMutableArray *favorites;
    NSMutableArray *sectionTitles;
    NSMutableArray *sectionArrays;
    AwfulForum *goldmine;
}

@property (nonatomic, retain) NSMutableArray *favorites;

-(void)signOut;

-(void)makeFavorite : (UIButton *)sender;
-(void)removeFavorite : (UIButton *)sender;

-(void)updateSignedIn;
-(void)hitDone;

@end
