//
//  NSManagedObject+Lazy.h
//  Awful
//
//  Created by me on 7/31/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (Lazy)
-(void) setContentForCell:(UITableViewCell*)cell;
@end
