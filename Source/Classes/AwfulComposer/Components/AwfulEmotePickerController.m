//
//  AwfulEmoteChooser.m
//  Awful
//
//  Created by me on 5/6/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEmotePickerController.h"
#import "AwfulImagePickerGridCell.h"

#import "AwfulEmote.h"
#import "AwfulHTTPClient+Emoticons.h"
#import "FVGifAnimation.h"

@interface AwfulEmotePickerController ()

@end

@implementation AwfulEmotePickerController
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
    _columnWidth = 124;
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

-(CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

- (void)configureCell:(UITableViewCell*)cell inRowAtIndexPath:(NSIndexPath *)indexPath {
    AwfulImagePickerGridCell *gridCell = (AwfulImagePickerGridCell*)cell;
    [super configureCell:cell inRowAtIndexPath:indexPath];
    AwfulEmote* emote = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = emote.code;
    cell.imageView.image = [UIImage imageNamed:emote.filename.lastPathComponent];
    gridCell.showLabel = YES;
    
    
    gridCell.imagePath = emote.filename;
    
    
    /*
     if (!iv.image) {
     //not in the bundle, check to see if it's a local path
     NSURL *url = [NSURL URLWithString:emote.filename];
     
     if (url.isFileURL) {
     iv.image = [UIImage imageWithContentsOfFile:url.path];
     
     }
     else {
     NSLog(@"would load %@",emote.filename);
     [[AwfulHTTPClient sharedClient] cacheEmoticon:emote
     onCompletion:^(NSMutableArray *messages) {
     //[self finishedRefreshing];
     }
     onError:^(NSError *error) {
     //[self finishedRefreshing];
     [ApplicationDelegate requestFailed:error];
     }];
     
     }
     
     
     
     //NSLog(@"loading emote %@", emote.code);
     
     
     */
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

-(void) gridView:(UITableView *)tableView didSelectCellInRowAtIndexPath:(NSIndexPath *)indexPath {
    AwfulEmote *selected = (AwfulEmote*)[self.fetchedResultsController objectAtIndexPath:indexPath];
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


@end
