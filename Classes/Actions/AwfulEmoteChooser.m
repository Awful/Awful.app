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


-(void) configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath*)indexPath {
    AwfulEmote* emote = [self.fetchedResultsController objectAtIndexPath:indexPath];
    
    cell.textLabel.text = emote.code;
    cell.detailTextLabel.text = emote.urlString;
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
