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
#import "AwfulNetworkEngine.h"

#define MAX_EMOTE_WIDTH 100.0f

@interface AwfulEmoteChooser ()

@end

@implementation AwfulEmoteChooser

-(void) awakeFromNib {
    _entity = @"AwfulEmote";
    _request = [NSFetchRequest new];
    NSEntityDescription *entityDesc = [NSEntityDescription entityForName:_entity 
                                                  inManagedObjectContext:ApplicationDelegate.managedObjectContext];
    [_request setEntity:entityDesc];

            [_request setSortDescriptors:
             [NSArray arrayWithObject:
              [NSSortDescriptor sortDescriptorWithKey:@"code" ascending:YES]
              ]
             ];
    
}

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

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    CGFloat width = tableView.frame.size.width;
    _numIconsPerRow = width/MAX_EMOTE_WIDTH;
    
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    NSLog(@"row count: %i", [sectionInfo numberOfObjects]/_numIconsPerRow);
    return [sectionInfo numberOfObjects]/_numIconsPerRow;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell;
    NSManagedObject *obj = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    
    cell = [tableView dequeueReusableCellWithIdentifier:obj.entity.managedObjectClassName];
    
    if (cell == nil)
        cell = [[AwfulTableViewCellEmoticonMultiple alloc] initWithStyle:UITableViewCellStyleDefault 
                                                         reuseIdentifier:obj.entity.managedObjectClassName];
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    AwfulTableViewCellEmoticonMultiple *gridCell = (AwfulTableViewCellEmoticonMultiple*)cell;
    
    NSMutableArray *emotes = [NSMutableArray new];
    
    for(int x = indexPath.row * _numIconsPerRow; x< (indexPath.row * _numIconsPerRow) + (_numIconsPerRow); x++) {
        AwfulEmote *emote = [self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForRow:x 
                                                                                                inSection:0]];
        [emotes addObject:emote];
    }
    
    [gridCell setContent:emotes];
}



-(void) refresh {
    [self.networkOperation cancel];
    self.reloading = YES;
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine refreshEmotesOnCompletion:nil onError:nil];
    /*
                             onCompletion:^(NSMutableArray *threads) {
        self.pages.currentPage = pageNum;
        if(pageNum == 1) {
            [self.awfulThreads removeAllObjects];
        }
        [self acceptThreads:threads];
        [self finishedRefreshing];
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        [AwfulUtil requestFailed:error];
    }];
     */
}

@end
