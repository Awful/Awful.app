//
//  ScrapingError.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-26.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import Foundation

public enum ScrapingError: LocalizedError {
    case missingExpectedElement(String)
    case missingRequiredValue(String)

    public var errorDescription: String? {
        return LocalizedString("error.scraping")
    }
}
