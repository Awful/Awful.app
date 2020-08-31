//  PostIconPersistence.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import Foundation

internal extension PostIcon {
    func update(_ tag: ThreadTag) {
        if !id.isEmpty, id != tag.threadTagID { tag.threadTagID = id }
        if let imageName = url.map(ThreadTag.imageName), imageName != tag.imageName { tag.imageName = imageName }
    }
}


internal extension PostIconListScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> (primary: [ThreadTag], secondary: [ThreadTag]) {
        let helper = PostIconPersistenceHelper(context: context, icons: primaryIcons + secondaryIcons)
        helper.performFetch()
        return (primary: primaryIcons.map(helper.upsert),
                secondary: secondaryIcons.map(helper.upsert))
    }
}


internal class PostIconPersistenceHelper {
    private let context: NSManagedObjectContext
    private let icons: [PostIcon]
    private var byID: [String: ThreadTag] = [:]
    private var byImageName: [String: ThreadTag] = [:]

    init(context: NSManagedObjectContext, icons: [PostIcon]) {
        self.context = context
        self.icons = icons
    }

    func performFetch() {
        let tags = ThreadTag.fetch(in: context) {
            let threadTagIDs = icons
                .map { $0.id }
                .filter { !$0.isEmpty }
            let imageNames = icons
                .compactMap { $0.url }
                .map(ThreadTag.imageName)
                .filter { !$0.isEmpty }
            $0.predicate = .or(
                .init("\(\ThreadTag.threadTagID) IN \(threadTagIDs)"),
                .init("\(\ThreadTag.imageName) IN \(imageNames)")
            )
            $0.returnsObjectsAsFaults = false
        }
        for tag in tags {
            if let id = tag.threadTagID {
                byID[id] = tag
            }

            if let imageName = tag.imageName {
                byImageName[imageName] = tag
            }
        }
    }

    func upsert(_ icon: PostIcon) -> ThreadTag {
        let fromID = icon.id.isEmpty ? nil : byID[icon.id]
        let imageName = icon.url.map(ThreadTag.imageName)
        let fromImageName = imageName.flatMap { byImageName[$0] }
        let tag = fromID ?? fromImageName ?? ThreadTag.insert(into: context)
        icon.update(tag)

        if fromID == nil, let id = tag.threadTagID { byID[id] = tag }
        if fromImageName == nil, let imageName = imageName { byImageName[imageName] = tag }

        return tag
    }
}
