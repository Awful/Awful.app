//  CachePruner.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

final class CachePruner: Operation {
    let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext context: NSManagedObjectContext) {
        managedObjectContext = context
        super.init()
    }
    
    override func main() {
        let context = managedObjectContext
        context.performAndWait {
            let allEntities = context.persistentStoreCoordinator!.managedObjectModel.entities as [NSEntityDescription]
            let prunableEntities = allEntities.filter { $0.attributesByName["lastModifiedDate"] != nil }
            
            var candidateObjectIDs = [NSManagedObjectID]()
            let components = NSDateComponents()
            components.day = -7
            let calendar = Calendar(calendarIdentifier: Calendar.Identifier.gregorian)!
            let oneWeekAgo = calendar.date(byAdding: components as DateComponents, to: NSDate() as Date, options: [])!
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest()
            fetchRequest.predicate = Predicate(format: "lastModifiedDate < %@", oneWeekAgo)
            fetchRequest.resultType = .managedObjectIDResultType
            for entity in prunableEntities {
                fetchRequest.entity = entity
                var result: [NSManagedObjectID] = []
                do {
                    result = try context.fetch(fetchRequest) as! [NSManagedObjectID]
                    candidateObjectIDs += result
                }
                catch {
                    NSLog("[\(Mirror(reflecting: self)) \(#function)] error fetching: \(error)")
                }
            }
            
            // An object isn't expired if it's actively in use. Since lastModifiedDate gets updated on save, it's possible to have objects actively in use with an expired lastModifiedDate, and we don't want to delete those.
            let expiredObjectIDs = candidateObjectIDs.filter { self.managedObjectContext.registeredObject(for: $0) == nil }
            
            for objectID in expiredObjectIDs {
                let object = context.object(with: objectID)
                context.delete(object)
            }
            
            do {
                try context.save()
            }
            catch {
                // Would prefer fatalError() but that doesn't show up in Crashlytics logs.
                NSException(name: NSExceptionName.genericException, reason: "error saving: \(error)", userInfo: nil).raise()
            }
        }
    }
}
