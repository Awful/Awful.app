//
//  TemplateListViewController.m
//  Awful
//
//  Created by Nolan Waite on 12-05-27.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "TemplateListViewController.h"
#import "ReloadingWebViewController.h"

@interface TemplateListViewController ()

@property (strong, nonatomic) NSURL *folder;

@property (strong) NSArray *templates;

@end

@implementation TemplateListViewController

- (id)initWithFolder:(NSURL *)folder
{
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.folder = folder;
        self.title = @"Awful Template Tester";
    }
    return self;
}

@synthesize folder = _folder;
@synthesize templates = _templates;

- (id)initWithStyle:(UITableViewStyle)style
{
    NSAssert(NO, @"need a folder");
    return nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Templates"
                                                                             style:0
                                                                            target:nil
                                                                            action:NULL];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *keys = [NSArray arrayWithObject:NSURLNameKey];
    NSArray *contents = [fileManager contentsOfDirectoryAtURL:self.folder
                                   includingPropertiesForKeys:keys
                                                      options:NSDirectoryEnumerationSkipsHiddenFiles
                                                        error:NULL];
    id justCSS = ^(NSURL *url, NSUInteger _, BOOL *__) {
        return [url.pathExtension compare:@"css"
                                  options:NSCaseInsensitiveSearch] == NSOrderedSame;
    };
    NSIndexSet *cssFileIndexes = [contents indexesOfObjectsPassingTest:justCSS];
    NSArray *cssContents = [contents objectsAtIndexes:cssFileIndexes];
    
    self.templates = [cssContents valueForKey:@"lastPathComponent"];
    [self.tableView reloadData];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.templates count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:CellIdentifier];
    }
    
    cell.textLabel.text = [self.templates objectAtIndex:indexPath.row];
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *template = [self.templates objectAtIndex:indexPath.row];
    NSURL *url = [self.folder URLByAppendingPathComponent:template];
    ReloadingWebViewController *viewer = [[ReloadingWebViewController alloc] initWithTemplate:url];
    [self.navigationController pushViewController:viewer animated:YES];
}

@end
