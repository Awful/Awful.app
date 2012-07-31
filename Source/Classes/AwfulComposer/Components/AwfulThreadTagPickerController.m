//
//  AwfulThreadTagPickerController.m
//  Awful
//
//  Created by me on 7/30/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadTagPickerController.h"
#import "AwfulEmote.h"

@interface AwfulThreadTagPickerController ()

@end

@implementation AwfulThreadTagPickerController

- (id)initWithForum:(AwfulForum *)forum {
    self = [super init];
    if (self) {
        // Custom initialization
    [self setEntityName:@"AwfulEmote"
              predicate:nil//@"forum = %@"
                   sort:@"code"
             sectionKey:nil
     ];
    }
    return self;
}

-(void) viewDidLoad {
    [super viewDidLoad];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    cell = [tableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                                         reuseIdentifier:@"UITableViewCell"];

    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

-(void) configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    AwfulEmote* emote = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = emote.code;
    cell.detailTextLabel.text = emote.desc;
    cell.imageView.image = [UIImage imageNamed:emote.filename.lastPathComponent];
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
