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
#import "AwfulHTTPClient+Emoticons.h"

#define MAX_EMOTE_WIDTH 90

@interface AwfulEmoteChooser ()

@end

@implementation AwfulEmoteChooser
@synthesize searchBar = _searchBar;

-(id) init {
    self = [super init];
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
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 200, 44)];
    self.tableView.tableHeaderView = self.searchBar;
    //imagesToCache = [NSMutableArray new];
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
	// Do any additional setup after loading the view.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

-(void) viewDidAppear:(BOOL)animated {
    [self.searchBar becomeFirstResponder];
}

-(NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //if (!_numIconsPerRow) {
        CGFloat width = self.view.frame.size.width;
        _numIconsPerRow = width/125;
    //}
    
    id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
    
    if ([sectionInfo numberOfObjects] == 0) return 0;
    int rows = [sectionInfo numberOfObjects]/_numIconsPerRow + 1;
    return rows;
}

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    NSManagedObject *obj = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    
    cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil)
        cell = [[AwfulTableViewCellEmoticonMultiple alloc] initWithStyle:UITableViewCellStyleDefault 
                                                         reuseIdentifier:@"AwfulTableViewCellEmoticonMultiple"];
    
    
    UIGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedCell:)];
    [cell addGestureRecognizer:tap];
    [self configureCell:cell atIndexPath:indexPath];
     
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
        

        
    }
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tappedCell:)];
    [gridCell addGestureRecognizer:tap];
    
    [gridCell setContent:emotes];
    gridCell.showCodes = YES;//(self.searchBar.text.length > 0);
     
}

-(void) refresh {
    [self.networkOperation cancel];
    self.reloading = YES;
    self.networkOperation = [[AwfulHTTPClient sharedClient] emoticonListOnCompletion:^(NSMutableArray *messages) {
        [self finishedRefreshing];
    } 
                                                                                   onError:^(NSError *error) {
                                                                                       [self finishedRefreshing];
                                                                                       [ApplicationDelegate requestFailed:error];
                                                                                   }];
}

-(void) tappedCell:(UITapGestureRecognizer *)sender  {
    AwfulTableViewCellEmoticonMultiple *cell = (AwfulTableViewCellEmoticonMultiple*)sender.view;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    CGPoint location = [sender locationInView:sender.view];
    
    int emoteIndex = location.x / 125;
    NSIndexPath *emotePath = [NSIndexPath indexPathForRow:(indexPath.row*_numIconsPerRow + emoteIndex)
                                                inSection:0];
    
    AwfulEmote *selected = (AwfulEmote*)[self.fetchedResultsController objectAtIndexPath:emotePath];
    //NSLog(@"emote: %@", selected.code);

    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulEmoteChosenNotification object:selected];
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
        //[[NSNotificationCenter defaultCenter] postNotificationName:NOTIFY_EMOTE_FILTERED 
        //                                                    object:[NSNumber numberWithInt:self.fetchedResultsController.fetchedObjects.count]];
    }
}

#pragma mark fetchedresultscontroller
//got to override this because there's multiple emotes per row

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    
    NSIndexPath* calculatedPath = [NSIndexPath indexPathForRow:(indexPath.row/_numIconsPerRow) inSection:0];
    
    [super controller:controller didChangeObject:anObject atIndexPath:calculatedPath forChangeType:type newIndexPath:calculatedPath];
}


@end
