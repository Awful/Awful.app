//
//  AwfulEmoteChooser.m
//  Awful
//
//  Created by me on 5/6/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEmoteChooser.h"
#import "AwfulTableViewCellEmoticonMultiple.h"
#import "AwfulEmote.h"

@interface AwfulEmoteChooser ()

@end

@implementation AwfulEmoteChooser


- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}


-(int) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 20;
}

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}
 
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    //NSManagedObject *obj = [_fetchedResultsController objectAtIndexPath:indexPath];


    //cell = [tableView dequeueReusableCellWithIdentifier:obj.entity.managedObjectClassName];

    if (cell == nil)
        cell = [[AwfulTableViewCellEmoticonMultiple alloc] initWithStyle:UITableViewCellStyleDefault 
                                                 reuseIdentifier:@"emoteCell"];

    //NSMutableArray *emotes = [NSMutableArray new];

    //for(int x = indexPath.row * _numIconsPerRow; x< (indexPath.row * _numIconsPerRow) + (_numIconsPerRow); x++) {
        //AwfulEmote *emote = [_fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForRow:x 
        //                                                                                       inSection:0]];
        //[emotes addObject:emote];
        
    //}

    //[gridCell setContent:emotes];
return cell;
}

-(void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
NSLog(@"prepare...");
}

@end
