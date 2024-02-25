//  ThemeNameTransformer.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulTheming
import Foundation

final class ThemeNameTransformer: ValueTransformer {

    override class func transformedValueClass() -> AnyClass {
        return NSString.self
    }

    override class func allowsReverseTransformation() -> Bool {
        return true
    }

    override func transformedValue(_ value: Any?) -> Any? {
        return (value as? String)
            .flatMap(Theme.theme(named:))
            .map { $0.descriptiveName }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        return (value as? String)
            .flatMap(Theme.theme(describedAs:))
            .map { $0.name }
    }

    static let name = NSValueTransformerName("theme-name")
}
