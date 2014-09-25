//  SmileyScraper.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

public func scrapeSmileys(#HTML: NSString, intoManagedObjectContext context: NSManagedObjectContext, error: NSErrorPointer) -> Bool {
    let document = HTMLDocument(string: HTML)
    // TODO upsert, not insert. And do it in batches maybe.
    // TODO handle parsing errors
    // TODO imageData
    let container = document.firstNodeMatchingSelector(".smilie_list")
    let headers = container.nodesMatchingSelector("h3") as [HTMLElement]
    let lists = container.nodesMatchingSelector(".smilie_group") as [HTMLElement]
    for (header, list) in Zip2(headers, lists) {
        let sectionName = header.textContent
        for item in list.nodesMatchingSelector("li") {
            context.performBlock {
                let smiley = Smiley(managedObjectContext: context)
                smiley.text = item.firstNodeMatchingSelector(".text").textContent
                let img = item.firstNodeMatchingSelector("img")
                smiley.imageURL = img.objectForKeyedSubscript("src") as? NSString
                smiley.section = sectionName
                smiley.summary = img.objectForKeyedSubscript("title") as? NSString
            }
        }
    }
    
    var ok = false
    context.performBlockAndWait {
        ok = context.save(error)
    }
    return ok
}
