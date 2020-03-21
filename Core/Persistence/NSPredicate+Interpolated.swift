//  NSPredicate+Interpolated.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension NSPredicate {

    /**
     Initializes a predicate deriving a format string and arguments from string interpolation.

     Types supported for interpolation:

     - `CVarArg`
     - `KeyPath` (from an `NSObject` root to a `CVarArg` value)
     */
    convenience init(_ interpolated: Interpolation) {
        self.init(format: interpolated.format, argumentArray: interpolated.arguments)
    }

    struct Interpolation: ExpressibleByStringInterpolation {
        fileprivate var format: String
        fileprivate var arguments: [CVarArg] = []

        init(stringLiteral value: String) {
            format = value
        }

        init(stringInterpolation: StringInterpolation) {
            format = stringInterpolation.format
            arguments = stringInterpolation.arguments
        }

        struct StringInterpolation: StringInterpolationProtocol {
            fileprivate var format = ""
            fileprivate var arguments: [CVarArg] = []

            init(literalCapacity: Int, interpolationCount: Int) {
                format.reserveCapacity(literalCapacity)
            }

            mutating func appendLiteral(_ literal: String) {
                format.append(literal)
            }

            mutating func appendInterpolation<Root, Value>(
                _ value: KeyPath<Root, Value>
            ) where Root: NSObject, Value: CVarArg {
                format.append("%K")
                arguments.append(value.stringValue)
            }

            mutating func appendInterpolation<Root, Value>(
                _ value: KeyPath<Root, Value?>
            ) where Root: NSObject, Value: CVarArg {
                format.append("%K")
                arguments.append(value.stringValue)
            }

            mutating func appendInterpolation(_ value: CVarArg) {
                format.append("%@")
                arguments.append(value)
            }
        }
    }
}
