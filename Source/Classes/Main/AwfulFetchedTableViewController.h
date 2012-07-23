//
//  AwfulFetchedTableViewController.h
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"

@interface AwfulFetchedTableViewController : AwfulTableViewController <NSFetchedResultsControllerDelegate> {    
    NSString *sectionKey, *_entity;
    NSFetchRequest *_request;
    
    @protected
    NSFetchedResultsController *_fetchedResultsController;
}

-(void) setEntityName:(NSString*)entity predicate:(id)predicate sort:(id)sort sectionKey:(NSString*)sectionKeyPath;

@property (nonatomic,strong) NSFetchedResultsController* fetchedResultsController;
@property (nonatomic,strong) NSFetchRequest *request;
@property (nonatomic,strong) NSString* sectionKey;
@property (nonatomic,strong) NSPredicate* predicate;
@property (nonatomic,strong) NSArray *sortDescriptors;
@property (nonatomic,strong) NSEntityDescription *entityDescription;

@end
