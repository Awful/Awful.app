//  SmileyScraper.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

public class SmileyScraper: NSObject {
    public let managedObjectContext: NSManagedObjectContext
    
    public required init(managedObjectContext context: NSManagedObjectContext) {
        managedObjectContext = context
        super.init()
    }
    
    public func scrapeSmileys(#HTML: NSString, error: NSErrorPointer) -> Bool {
        let document = HTMLDocument(string: HTML)
        // TODO upsert, not insert. And do it in batches maybe.
        // TODO handle parsing errors
        let container = document.firstNodeMatchingSelector(".smilie_list")
        let headers = container.nodesMatchingSelector("h3") as [HTMLElement]
        let lists = container.nodesMatchingSelector(".smilie_group") as [HTMLElement]
        for (header, list) in Zip2(headers, lists) {
            let sectionName = header.textContent
            for item in list.nodesMatchingSelector("li") {
                managedObjectContext.performBlock {
                    let smiley = Smiley(managedObjectContext: self.managedObjectContext)
                    smiley.text = item.firstNodeMatchingSelector(".text").textContent
                    let img = item.firstNodeMatchingSelector("img")
                    smiley.imageURL = img.objectForKeyedSubscript("src") as? NSString
                    smiley.section = sectionName
                    smiley.summary = img.objectForKeyedSubscript("title") as? NSString
                }
            }
        }
        
        var ok = false
        managedObjectContext.performBlockAndWait {
            ok = self.managedObjectContext.save(error)
        }
        return ok
    }
    
}
