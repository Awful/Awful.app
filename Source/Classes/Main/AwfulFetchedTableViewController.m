//
//  AwfulFetchedTableViewController.m
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFetchedTableViewController.h"

@interface AwfulFetchedTableViewController ()
@end

@implementation AwfulFetchedTableViewController
@synthesize fetchedResultsController = _fetchedResultsController;
@synthesize entityDescription = _entityDescription;
@synthesize request = _request;
@synthesize predicate = _predicate;
@synthesize sortDescriptors = _sortDescriptors;
@synthesize sectionKey = _sectionKey;

-(id) initWithEntity:(NSString*)entity predicate:(id)predicate sort:(id)sort sectionKey:(NSString*)sectionKeyPath {
    self = [super init];

    [self setEntityName:entity predicate:predicate sort:sort sectionKey:sectionKeyPath];
    
    return self;
}

-(void) setEntityName:(NSString*)entity predicate:(id)predicate sort:(id)sort sectionKey:(NSString*)sectionKeyPath {
    self.entityDescription = [NSEntityDescription entityForName:entity 
                                                  inManagedObjectContext:ApplicationDelegate.managedObjectContext];
    self.sectionKey = sectionKeyPath;
    
    if (predicate) {
        if ([predicate isKindOfClass:[NSPredicate class]])
            self.predicate = predicate;
        else if ([predicate isKindOfClass:[NSString class]])
            self.predicate = [NSPredicate predicateWithFormat:predicate];
    }
    
    if (sort) {
        if ([sort isKindOfClass:[NSArray class]])
            self.sortDescriptors = sort;
        else if ([sort isKindOfClass:[NSSortDescriptor class]])
            self.sortDescriptors = [NSArray arrayWithObject:sort];
        else if ([sort isKindOfClass:[NSString class]]) {
            self.sortDescriptors = [NSArray arrayWithObject:
                                    [NSSortDescriptor sortDescriptorWithKey:sort ascending:YES]
                                    ];
        }
    }
    else {
        //need a sort descriptor
        abort();
    } 
    
    self.request = [[NSFetchRequest alloc] initWithEntityName:entity];
    self.request.predicate = self.predicate;
    self.request.sortDescriptors = self.sortDescriptors;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSError *error;
	if (![[self fetchedResultsController] performFetch:&error]) {
		// Update to handle the error appropriately.
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		exit(-1);  // Fail
	}
    
    self.tableView.sectionIndexMinimumDisplayRowCount = NSIntegerMax;
    
}

- (NSFetchedResultsController *)fetchedResultsController {
    
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    _fetchedResultsController = 
    [[NSFetchedResultsController alloc] initWithFetchRequest:self.request 
                                        managedObjectContext:ApplicationDelegate.managedObjectContext
                                          sectionNameKeyPath:self.sectionKey 
                                                   cacheName:nil];
    
    //self.fetchedResultsController = theFetchedResultsController;
    //NSLog(@"results sections count:%i", _fetchedResultsController.sections.count);
    _fetchedResultsController.delegate = self;
    
    //[sort release];
    
    return _fetchedResultsController;    
    
}

#pragma mark table view
-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return _fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    id <NSFetchedResultsSectionInfo> sectionInfo = [[_fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    NSManagedObject *obj = [_fetchedResultsController objectAtIndexPath:indexPath];
    
    
    cell = [tableView dequeueReusableCellWithIdentifier:obj.entity.managedObjectClassName];
    if (cell == nil) {
        //if ([obj respondsToSelector:@selector(tableViewCell)])
        //    cell = [(id)obj tableViewCell];
        //else
            cell = [[UITableViewCell alloc] initWithStyle:(UITableViewCellStyleSubtitle) 
                                          reuseIdentifier:obj.entity.managedObjectClassName];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}


- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section { 
    id <NSFetchedResultsSectionInfo> sectionInfo = [[_fetchedResultsController sections] objectAtIndex:section];
    return [sectionInfo name];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return [_fetchedResultsController sectionIndexTitles];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    return [_fetchedResultsController sectionForSectionIndexTitle:title atIndex:index];
}

/*
#pragma mark on demand image loading
-(void)loadImageData:(AwfulIcon*)icon inCell:(UITableViewCell*)cell {
    if(icon.imageData == nil) {
        dispatch_async(imageQueue, ^{
            if (icon.imageData == nil) {
                [icon setImageData:[NSData dataWithContentsOfURL:[NSURL URLWithString:icon.filename]]];
                
                NSLog(@"Loaded %@", icon.filename);
                if ([cell respondsToSelector:@selector(setThreadIconData:)])
                    [cell performSelectorOnMainThread:@selector(setThreadIconData:) 
                                           withObject:icon.imageData 
                                        waitUntilDone:YES];
                
                [APPDELEGATE saveData];
                sleep(.5);
            }
        }
                       
                       );
        
    }
}
*/
#pragma mark fetch delegate
- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller is about to start sending change notifications, so prepare the table view for updates.
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath {
    //NSLog(@"didChangeObject %i: row %i -> %i", type, indexPath.row, newIndexPath.row);
    
    UITableView *tableView = self.tableView;
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] withRowAnimation:UITableViewRowAnimationTop];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationTop];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                             withRowAnimation:UITableViewRowAnimationTop];
            
            [tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath] 
                             withRowAnimation:(UITableViewRowAnimationTop)];
            // Reloading the section inserts a new row and ensures that titles are updated appropriately.
            //[tableView reloadSections:[NSIndexSet indexSetWithIndex:newIndexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            //[self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            [self performSelectorOnMainThread:@selector(reloadRow:) withObject:indexPath waitUntilDone:NO];
            //[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
            //                withRowAnimation:(UITableViewRowAnimationFade)];
            break;
    }
}

-(void) reloadRow:(NSIndexPath*)indexPath {
    [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                          withRowAnimation:(UITableViewRowAnimationFade)];
}


- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type {
    //NSLog(@"didchangesection: %@", sectionIndex);
    
    switch(type) {
            
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}


- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    // The fetch controller has sent all current change notifications, so tell the table view to process all updates.
    [self.tableView endUpdates];
    //if (pullToReload)
    //    [pullToReload dataSourceDidFinishLoadingNewData];
}


@end
