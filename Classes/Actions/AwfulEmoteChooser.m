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
#import "AwfulEmote+AwfulMethods.h"
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
    
    UIGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedCell:)];
    [cell addGestureRecognizer:tap];
    return cell;
}

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    AwfulTableViewCellEmoticonMultiple *gridCell = (AwfulTableViewCellEmoticonMultiple*)cell;
    
    NSMutableArray *emotes = [NSMutableArray new];
    
    for(int x = indexPath.row * _numIconsPerRow; x< (indexPath.row * _numIconsPerRow) + (_numIconsPerRow); x++) {
        AwfulEmote *emote = [self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForRow:x 
                                                                                                inSection:0]];
        [emotes addObject:emote];
        
        if (!emote.cached) {
            NSLog(@"loading emote %@", emote.code);
            
            [ApplicationDelegate.awfulNetworkEngine cacheImage:emote 
                                                  onCompletion:^{
                                                      [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                                                                            withRowAnimation:(UITableViewRowAnimationFade)];
                                                  } 
                                                       onError:nil];
             
        }
        
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

-(void) tappedCell:(UITapGestureRecognizer *)sender  {
    AwfulTableViewCellEmoticonMultiple *cell = sender.view;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    CGPoint location = [sender locationInView:sender.view];
    
    int emoteIndex = location.x / MAX_EMOTE_WIDTH;
    NSIndexPath *emotePath = [NSIndexPath indexPathForRow:(indexPath.row*_numIconsPerRow + emoteIndex)
                                                inSection:0];
    
    AwfulEmote *selected = (AwfulEmote*)[self.fetchedResultsController objectAtIndexPath:emotePath];
    NSLog(@"emote: %@", selected.code);
}

@end
