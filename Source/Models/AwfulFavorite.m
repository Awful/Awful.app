#import "AwfulFavorite.h"

@implementation AwfulFavorite

// Custom logic goes here.
-(id) init {
    self = [super initWithEntity:[NSEntityDescription entityForName:@"Favorite"
                                             inManagedObjectContext:ApplicationDelegate.managedObjectContext
                                  ]
  insertIntoManagedObjectContext:ApplicationDelegate.managedObjectContext];
    
    return self;
}
@end
