//
//  AwfulThreadTagPickerController.m
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadTagPickerController.h"
#import "AwfulEmote.h"
#import "AwfulHTTPClient+ThreadTags.h"

@interface AwfulThreadTagPickerController ()

@end

@implementation AwfulThreadTagPickerController
@synthesize forum = _forum;

- (id)initWithForum:(AwfulForum *)forum {
    self = [super init];
    if (self) {
        // Custom initialization
    [self setEntityName:@"AwfulThreadTag"
              predicate:nil//@"forum = %@"
                   sort:@"alt"
             sectionKey:nil
     ];
    }
    return self;
}

-(void) viewDidLoad {
    [super viewDidLoad];
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
    AwfulEmote* emote = [self.fetchedResultsController objectAtIndexPath:indexPath];
    //cell.textLabel.text = emote.code;
    //cell.detailTextLabel.text = emote.desc;
    cell.imageView.image = [UIImage imageNamed:emote.filename.lastPathComponent];
    cell.textLabel.text = nil;
}


-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSManagedObject *tag = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:tag forKey:@"tag"];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulThreadTagPickedNotification
                                                        object:self
                                                      userInfo:userInfo
     ];
    
    [self.navigationController popViewControllerAnimated:YES];
}



@end
