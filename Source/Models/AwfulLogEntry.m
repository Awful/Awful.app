#import "AwfulLogEntry.h"


@implementation AwfulLogEntry
+(void) writeLogEntryWithLevel:(AwfulLogLevel)level category:(NSString *)category message:(NSString *)message {
    AwfulLogEntry* log = [AwfulLogEntry new];
    log.category = category;
    log.message = message;
    log.date = [NSDate date];
    [ApplicationDelegate.managedObjectContext save:nil];
    
}

-(void) setContentForCell:(UITableViewCell *)cell {
    cell.textLabel.text = self.message;
}

@end
