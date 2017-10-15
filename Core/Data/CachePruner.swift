//  CachePruner.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Foundation

final class CachePruner: Operation {
    let managedObjectContext: NSManagedObjectContext
    
    init(managedObjectContext context: NSManagedObjectContext) {
        managedObjectContext = context
        super.init()
    }
    
    override func main() {
        let context = managedObjectContext
        guard let storeCoordinator = context.persistentStoreCoordinator else { return }
        let allEntities = storeCoordinator.managedObjectModel.entities
        let prunableEntities = allEntities.filter { (entity: NSEntityDescription) -> Bool in entity.attributesByName["lastModifiedDate"] != nil }
        
        context.performAndWait { () -> Void in
            var components = DateComponents()
            components.day = -7
            let calendar = Calendar(identifier: .gregorian)
            let oneWeekAgo = calendar.date(byAdding: components, to: Date())!
            let fetchRequest: NSFetchRequest<NSManagedObjectID> = NSFetchRequest()
            fetchRequest.predicate = NSPredicate(format: "lastModifiedDate < %@", oneWeekAgo as NSDate)
            fetchRequest.resultType = .managedObjectIDResultType
            
            var candidateObjectIDs: [NSManagedObjectID] = []
            for entity in prunableEntities {
                fetchRequest.entity = entity
                do {
                    let result = try context.fetch(fetchRequest)
                    candidateObjectIDs.append(contentsOf: result)
                }
                catch {
                    NSLog("[\(Mirror(reflecting: self)) \(#function)] error fetching: \(error)")
                }
            }
            
            // An object isn't expired if it's actively in use. Since lastModifiedDate gets updated on save, it's possible to have objects actively in use with an expired lastModifiedDate, and we don't want to delete those.
            let expiredObjectIDs = candidateObjectIDs.filter { (id: NSManagedObjectID) -> Bool in context.registeredObject(for: id) == nil }
            
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
