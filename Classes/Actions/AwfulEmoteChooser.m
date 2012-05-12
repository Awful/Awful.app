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

@interface AwfulEmoteChooser ()

@end

@implementation AwfulEmoteChooser
@synthesize searchBar = _searchBar;

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
    
    self.tableView.tableHeaderView = self.searchBar;
    imagesToCache = [NSMutableArray new];
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
    
    int rows = [sectionInfo numberOfObjects]/_numIconsPerRow + 1;
    return rows;
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
    //NSLog(@"config cell %d", indexPath.row);
    
    NSMutableArray *emotes = [NSMutableArray new];
    
    for(int x = indexPath.row * _numIconsPerRow; x< (indexPath.row * _numIconsPerRow) + (_numIconsPerRow); x++) {
        //NSLog(@"load index %d", x);
        if (x >= self.fetchedResultsController.fetchedObjects.count) continue;
        AwfulEmote *emote = [self.fetchedResultsController objectAtIndexPath:[NSIndexPath indexPathForRow:x 
                                                                                                inSection:0]];
        
        [emotes addObject:emote];
        
        
        if (!emote.cached && [imagesToCache indexOfObject:emote] == NSNotFound) {
            //NSLog(@"loading emote %@", emote.code);
            [imagesToCache addObject:emote];
            [ApplicationDelegate.awfulNetworkEngine cacheImage:emote 
                                                  onCompletion:^{
                                                      //[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                                                        //                    withRowAnimation:(UITableViewRowAnimationFade)];
                                                  } 
                                                       onError:nil];
             
        }
        
    }
    
    [gridCell setContent:emotes];
    gridCell.showCodes = (self.searchBar.text.length > 0);
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
    AwfulTableViewCellEmoticonMultiple *cell = (AwfulTableViewCellEmoticonMultiple*)sender.view;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    CGPoint location = [sender locationInView:sender.view];
    
    int emoteIndex = location.x / MAX_EMOTE_WIDTH;
    NSIndexPath *emotePath = [NSIndexPath indexPathForRow:(indexPath.row*_numIconsPerRow + emoteIndex)
                                                inSection:0];
    
    AwfulEmote *selected = (AwfulEmote*)[self.fetchedResultsController objectAtIndexPath:emotePath];
    NSLog(@"emote: %@", selected.code);
    
    [self dismissModalViewControllerAnimated:YES];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFY_EMOTE_SELECTED object:selected];
}

#pragma mark Search Delegate
-(void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length > 0) {
        self.fetchedResultsController.fetchRequest.predicate = [NSPredicate predicateWithFormat:@"code contains[cd] %@", searchText];
    }
    else {
        self.fetchedResultsController.fetchRequest.predicate = nil;
    }
    
    [self.fetchedResultsController performFetch:nil];
    //NSLog(@"Filtering, got %d rows", self.fetchedResultsController.fetchedObjects.count);
    [self.tableView reloadData];

    if (self.fetchedResultsController.fetchedObjects.count < 5) {
        //notify parent to resize the popover
        [[NSNotificationCenter defaultCenter] postNotificationName:NOTIFY_EMOTE_FILTERED 
                                                            object:[NSNumber numberWithInt:self.fetchedResultsController.fetchedObjects.count]];
    }
}

#pragma mark fetchedresultscontroller
//got to override this because there's multiple emotes per row

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    NSIndexPath* calculatedPath = [NSIndexPath indexPathForRow:(indexPath.row/_numIconsPerRow) inSection:0];
    
    [super controller:controller didChangeObject:anObject atIndexPath:calculatedPath forChangeType:type newIndexPath:calculatedPath];
}


@end
