//  ArchivesBannerText.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Foundation

extension ArchivesTimeframe {
    /// "Archives view: {…}" with the three valid shapes: year only, month + year, or month + day + year.
    /// Shown in the banners the app pins above the forum and thread lists while archives mode is active.
    public var bannerText: String {
        let date: String
        if let month, (1...12).contains(month) {
            let monthName = Calendar.current.monthSymbols[month - 1]
            if let day {
                date = "\(monthName) \(day), \(year)"
            } else {
                date = "\(monthName) \(year)"
            }
        } else {
            date = String(year)
        }
        return "Archives view: \(date)"
    }
}
