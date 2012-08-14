#import "AwfulLogEntry.h"


@implementation AwfulLogEntry
+(void) writeLogEntryWithLevel:(AwfulLogLevel)level category:(NSString *)category className:(NSString *)className message:(NSString *)message {
    AwfulLogEntry* log = [AwfulLogEntry new];
    log.category = category;
    log.message = message;
    log.fromClass = className;
    log.date = [NSDate date];
    [ApplicationDelegate.managedObjectContext save:nil];
}

-(void) setContentForCell:(UITableViewCell *)cell {
    cell.textLabel.text = self.message;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ > %@", self.category, self.fromClass];
}

@end


@implementation NSObject (AwfulLogEntry)

-(void) writeAwfulLogEntryWithLevel:(AwfulLogLevel)level category:(NSString*)category message:(NSString*)message {
    [AwfulLogEntry writeLogEntryWithLevel:level category:category className:[self.class description] message:message];
}

+(void) writeLogEntryWithLevel:(AwfulLogLevel)level category:(NSString*) category message:(NSString*)message {
    
}

@end