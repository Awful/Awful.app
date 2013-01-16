//
//  AwfulCloudDataVisualizerViewController.m
//  Awful
//
//  Created by me on 1/16/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulCloudDataVisualizerViewController.h"
#import "AwfulAppState.h"

@interface AwfulCloudDataVisualizerViewController ()
@property (nonatomic) NSDictionary *store;
@end

@implementation AwfulCloudDataVisualizerViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _store = [[AwfulAppState sharedAppState] awfulCloudStore].dictionaryRepresentation;
        self.tableView.editing = YES;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
#warning Potentially incomplete method implementation.
    // Return the number of sections.
    return self.store.allKeys.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    NSArray *keys = self.store.allKeys;
    id obj = [self.store objectForKey:keys[section]];
    
    if ([obj isKindOfClass:[NSArray class]]) {
        return [obj count];
    }
        
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    //static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:(UITableViewCellStyleValue1) reuseIdentifier:@"Cell"];
    
    NSArray *keys = self.store.allKeys;
    id obj = [self.store objectForKey:keys[indexPath.section]];
    
    if ([obj isKindOfClass:[NSArray class]]) {
        id innerObj = [obj objectAtIndex:indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"%@",innerObj];
    } else if ([obj isKindOfClass:[NSData class]]) {
        cell.textLabel.text = @"NSData";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%i", [obj length]];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", obj];
    }
    
    return cell;
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSArray *keys = self.store.allKeys;
    return keys[section];
}

-(BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

-(void) tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    
    NSString *key = self.store.allKeys[indexPath.section];
    [[[AwfulAppState sharedAppState] awfulCloudStore] removeObjectForKey:key];
    [[[AwfulAppState sharedAppState] awfulCloudStore] synchronize];
    [self.tableView reloadData];
    
}

@end
