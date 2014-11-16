//  Helpers.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

extension AwfulManagedObject {
    class func numberOfObjectsInManagedObjectContext(context: NSManagedObjectContext) -> Int {
        let fetchRequest = NSFetchRequest(entityName: entityName())
        var error: NSError?
        let count = context.countForFetchRequest(fetchRequest, error: &error)
        assert(count != NSNotFound, "error fetching count: \(error!)")
        return count
    }
    
    class func fetchAllInManagedObjectContext(context: NSManagedObjectContext) -> [AnyObject]? {
        let fetchRequest = NSFetchRequest(entityName: entityName())
        var error: NSError?
        let results = context.executeFetchRequest(fetchRequest, error: &error)
        assert(results != nil, "error fetching: \(error!)")
        return results
    }
}
