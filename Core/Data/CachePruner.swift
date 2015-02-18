//  CachePruner.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

final class CachePruner: NSOperation {
    let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext context: NSManagedObjectContext) {
        managedObjectContext = context
        super.init()
    }
    
    override func main() {
        let context = managedObjectContext
        context.performBlockAndWait {
            let allEntities = context.persistentStoreCoordinator!.managedObjectModel.entities as [NSEntityDescription]
            let prunableEntities = allEntities.filter { $0.attributesByName["lastModifiedDate"] != nil }
            
            var candidateObjectIDs = [NSManagedObjectID]()
            let components = NSDateComponents()
            components.day = -7
            let calendar = NSCalendar(calendarIdentifier: NSGregorianCalendar)!
            let oneWeekAgo = calendar.dateByAddingComponents(components, toDate: NSDate(), options: nil)!
            let fetchRequest = NSFetchRequest()
            fetchRequest.predicate = NSPredicate(format: "lastModifiedDate < %@", oneWeekAgo)
            fetchRequest.resultType = .ManagedObjectIDResultType
            for entity in prunableEntities {
                fetchRequest.entity = entity
                var error: NSError?
                if let result = context.executeFetchRequest(fetchRequest, error: &error) as [NSManagedObjectID]? {
                    candidateObjectIDs += result
                } else {
                    NSLog("[%@ %@] error fetching: %@", reflect(self).summary, __FUNCTION__, error!)
                }
            }
            
            // An object isn't expired if it's actively in use. Since lastModifiedDate gets updated on save, it's possible to have objects actively in use with an expired lastModifiedDate, and we don't want to delete those.
            let expiredObjectIDs = candidateObjectIDs.filter { self.managedObjectContext.objectRegisteredForID($0) == nil }
            
            for objectID in expiredObjectIDs {
                let object = context.objectWithID(objectID)
                context.deleteObject(object)
            }
            
            var error: NSError?
            if !context.save(&error) {
                // Would prefer fatalError() but that doesn't show up in Crashlytics logs.
                NSException(name: NSGenericException, reason: "error saving: \(error!)", userInfo: nil).raise()
            }
        }
    }
}
