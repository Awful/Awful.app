//
//  NSManagedObject+Lazy.m
//  Awful
//
//  Created by me on 7/31/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "NSManagedObject+Lazy.h"

@implementation NSManagedObject (Lazy)
-(id) init {
    self = [self initWithEntity:[NSEntityDescription entityForName:[[self class] description]
                                             inManagedObjectContext:ApplicationDelegate.managedObjectContext
                                  ]
            
  insertIntoManagedObjectContext:ApplicationDelegate.managedObjectContext
            ];
    
    return self;
}
@end
