//  Smilie+Query.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Smilies

extension SmilieDataStore {
    func fetchSmilie(text: String) -> Smilie? {
        let request = NSFetchRequest<Smilie>(entityName: Smilie.entityName())
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "%K = %@", #keyPath(Smilie.text), text)
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = [#keyPath(Smilie.metadata)]
        return try! managedObjectContext.fetch(request).first
    }
}
