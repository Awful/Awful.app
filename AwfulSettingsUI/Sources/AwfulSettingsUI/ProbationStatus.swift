//  ProbationStatus.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import SwiftUI

/// The logged-in user's probation, shown in the account section whenever they're on probation. The host app supplies the text and image, which come from its own strings and assets.
public struct ProbationStatus {
    let summary: String
    let image: Image
    let showDetails: () -> Void

    public init(summary: String, image: Image, showDetails: @escaping () -> Void) {
        self.summary = summary
        self.image = image
        self.showDetails = showDetails
    }
}
