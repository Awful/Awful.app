//
//  AwfulThreadTagPickerController.m
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadTagPickerController.h"
#import "AwfulThreadTag.h"
#import "AwfulHTTPClient+ThreadTags.h"

@interface AwfulThreadTagPickerController ()

@end

@implementation AwfulThreadTagPickerController
@synthesize forum = _forum;

- (id)initWithDraft:(AwfulDraft*)draft inForum:(AwfulForum *)forum {
    self = [super init];
    if (self) {
        // Custom initialization
    [self setEntityName:@"AwfulThreadTag"
              predicate:nil//@"forum = %@"
                   sort:@"alt"
             sectionKey:nil
     ];
        self.draft = draft;
    }
    return self;
}

-(void) viewDidLoad {
    [super viewDidLoad];
    _columnWidth = 125;
    self.title = @"Thread Tags";
}

-(void) refresh {
    [self.networkOperation cancel];
    self.reloading = YES;
    self.networkOperation = [[AwfulHTTPClient sharedClient] threadTagListForForum:self.forum
                                                                     onCompletion:^(NSMutableArray *messages) {
                                                                         [self finishedRefreshing];
                                                                     }
                                                                             onError:^(NSError *error) {
                                                                                 [self finishedRefreshing];
                                                                                 [ApplicationDelegate requestFailed:error];
                                                                             }];
}

-(void) configureCell:(UITableViewCell *)cell inRowAtIndexPath:(NSIndexPath *)indexPath {
    [super configureCell:cell inRowAtIndexPath:indexPath];
    AwfulThreadTag* tag = [self.fetchedResultsController objectAtIndexPath:indexPath];
    //cell.textLabel.text = emote.code;
    //cell.detailTextLabel.text = emote.desc;
    //cell.imageView.image = [UIImage imageNamed:emote.filename.lastPathComponent];
    cell.textLabel.text = tag.alt;
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.textAlignment = UITextAlignmentCenter;
    
    cell.imageView.image = tag.image;
    if (tag.image) {
        cell.textLabel.text = nil;
    }
    
    
     if (!tag.image && tag.filename) {
       
         [[AwfulHTTPClient sharedClient] cacheThreadTag:tag
                                           onCompletion:^(NSMutableArray *messages) {
                                               //[self finishedRefreshing];
                                           }
                                                onError:^(NSError *error) {
                                                //[self finishedRefreshing];
                                                    [ApplicationDelegate requestFailed:error];
                                                }
          ];
     
     }
}

-(void) gridView:(UITableView *)tableView didSelectCellInRowAtIndexPath:(NSIndexPath *)indexPath {
    AwfulThreadTag *selected = (AwfulThreadTag*)[self.fetchedResultsController objectAtIndexPath:indexPath];
    self.draft.threadTag = selected;
    //[[NSNotificationCenter defaultCenter] postNotificationName:AwfulThreadTagPickedNotification object:selected];
    [self.navigationController popViewControllerAnimated:YES];
}

-(AwfulRefreshControl*) loadNextControl {
    return nil;
}



@end
