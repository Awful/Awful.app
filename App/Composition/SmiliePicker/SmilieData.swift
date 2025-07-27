//  SmilieData.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import CoreData
import Smilies

/// Thread-safe representation of a Smilie for use in SwiftUI views
struct SmilieData: Identifiable, Hashable {
    let id: NSManagedObjectID
    let text: String
    let imageData: Data?
    let imageUTI: String?
    let section: String?
    let summary: String?
    
    init(from smilie: Smilie) {
        self.id = smilie.objectID
        self.text = smilie.text
        self.imageData = smilie.imageData
        self.imageUTI = smilie.imageUTI
        self.section = smilie.section
        self.summary = smilie.summary
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(text)
    }
    
    static func == (lhs: SmilieData, rhs: SmilieData) -> Bool {
        lhs.text == rhs.text
    }
}
