//  Thread+Presentation.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore

extension AwfulThread {
    private var roundedRating: Int? {
        let rounded = lroundf(rating).clamp(0...5)
        return rounded != 0 ? rounded : nil
    }

    /// Name of an image suitable for showing the rating below the thread tag.
    var ratingImageName: String? {
        let rounded = lroundf(rating).clamp(0...5)
        return rounded != 0 ? "rating\(rating)" : nil
    }

    /// Name of an image suitable for showing the rating as the thread tag itself.
    var ratingTagImageName: String? {
        let rounded = round(rating * 2) / 2
        return String(format: "%.1fstars.png", rounded)
    }
}
