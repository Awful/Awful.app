//  Smilie+Query.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulPolls
import Smilies
import SwiftUI
import UIKit

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

extension PollHandlers {

    /// The app's poll handlers: smilies come from the bundled smilie store and animate via
    /// FLAnimatedImage.
    @MainActor static var awful: PollHandlers {
        PollHandlers(
            storedSmilie: { text in
                guard let smilie = SmilieDataStore.shared.fetchSmilie(text: text),
                      let data = smilie.imageData,
                      let image = UIImage(data: data)
                else { return nil }
                return (data, image.size)
            },
            animatedImageView: { data, id in
                AnyView(AnimatedImageView(data: data, imageID: id))
            }
        )
    }
}
