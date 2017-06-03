//  ScrapingError.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

public enum ScrapingError: LocalizedError {
    case missingExpectedElement(String)
    case missingRequiredValue(String)

    public var errorDescription: String? {
        return LocalizedString("error.scraping")
    }
}
