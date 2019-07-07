//  Scanner.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/**
 A thinly-wrapped `Foundation.Scanner`.

 iOS 13 introduced a much nicer Swift API for `Foundation.Scanner` and deprecated the ickier mapped interface from Objective-C. This means only the new methods are available in UIKit for Mac, but we need to support iOS 12 and below as well. So we hide the differences here. When our deployment target reaches iOS 13, you should be able to simply delete this class and everything will still Just Work.
 */
public final class Scanner {
    private let scanner: Foundation.Scanner

    public init(string: String) {
        scanner = .init(string: string)
    }

    public var string: String { scanner.string }

    public var currentIndex: String.Index {
        get {
            #if targetEnvironment(UIKitForMac)
            return scanner.currentIndex
            #else
            return String.Index(utf16Offset: scanner.scanLocation, in: string)
            #endif
        }
        set {
            #if targetEnvironment(UIKitForMac)
            scanner.currentIndex = newValue
            #else
            scanner.scanLocation = newValue.utf16Offset(in: string)
            #endif
        }
    }

    public var isAtEnd: Bool { scanner.isAtEnd }

    public var charactersToBeSkipped: CharacterSet? {
        get { scanner.charactersToBeSkipped }
        set { scanner.charactersToBeSkipped = newValue }
    }

    public var caseSensitive: Bool {
        get { scanner.caseSensitive }
        set { scanner.caseSensitive = newValue }
    }

    public var locale: Any? {
        get { scanner.locale }
        set { scanner.locale = newValue }
    }
}

extension Scanner {
    public enum NumberRepresentation {
        case decimal
        case hexadecimal

        @available(iOS 13.0, *)
        fileprivate var foundationValue: Foundation.Scanner.NumberRepresentation {
            switch self {
            case .decimal: return .decimal
            case .hexadecimal: return .hexadecimal
            }
        }
    }

    public func scanInt(representation: NumberRepresentation = .decimal) -> Int? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanInt(representation: representation.foundationValue)
        #else
        var result = Int()
        guard scanner.scanInt(&result) else { return nil }
        return result
        #endif
    }

    public func scanInt32(representation: NumberRepresentation = .decimal) -> Int32? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanInt32(representation: representation.foundationValue)
        #else
        switch representation {
        case .decimal:
            var result = Int32()
            guard scanner.scanInt32(&result) else { return nil }
            return result
        case .hexadecimal:
            var result = UInt32()
            guard scanner.scanHexInt32(&result) else { return nil }
            return Int32(clamping: result)
        }
        #endif
    }

    public func scanInt64(representation: NumberRepresentation = .decimal) -> Int64? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanInt64(representation: representation.foundationValue)
        #else
        switch representation {
        case .decimal:
            var result = Int64()
            guard scanner.scanInt64(&result) else { return nil }
            return result
        case .hexadecimal:
            var result = UInt64()
            guard scanner.scanHexInt64(&result) else { return nil }
            return Int64(clamping: result)
        }
        #endif
    }

    public func scanUInt64(representation: NumberRepresentation = .decimal) -> UInt64? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanUInt64(representation: representation.foundationValue)
        #else
        switch representation {
        case .decimal:
            var result = Decimal()
            guard scanner.scanDecimal(&result) else { return nil }
            return (result as NSDecimalNumber).uint64Value
        case .hexadecimal:
            var result = UInt64()
            guard scanner.scanHexInt64(&result) else { return nil }
            return result
        }
        #endif
    }

    public func scanFloat(representation: NumberRepresentation = .decimal) -> Float? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanFloat(representation: representation.foundationValue)
        #else
        var result = Float()
        switch representation {
        case .decimal:
            guard scanner.scanFloat(&result) else { return nil }
        case .hexadecimal:
            guard scanner.scanHexFloat(&result) else { return nil }
        }
        return result
        #endif
    }

    public func scanDouble(representation: NumberRepresentation = .decimal) -> Double? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanDouble(representation: representation.foundationValue)
        #else
        var result = Double()
        switch representation {
        case .decimal:
            guard scanner.scanDouble(&result) else { return nil }
        case .hexadecimal:
            guard scanner.scanHexDouble(&result) else { return nil }
        }
        return result
        #endif
    }

    public func scanDecimal() -> Decimal? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanDecimal()
        #else
        var result = Decimal()
        guard scanner.scanDecimal(&result) else { return nil }
        return result
        #endif
    }

    public func scanString(_ searchString: String) -> String? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanString(searchString)
        #else
        var result: NSString!
        guard scanner.scanString(searchString, into: &result) else { return nil }
        return result as String
        #endif
    }

    public func scanCharacters(from set: CharacterSet) -> String? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanCharacters(from: set)
        #else
        var result: NSString!
        guard scanner.scanCharacters(from: set, into: &result) else { return nil }
        return result as String
        #endif
    }

    public func scanUpToString(_ substring: String) -> String? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanUpToString(substring)
        #else
        var result: NSString!
        guard scanner.scanUpTo(substring, into: &result) else { return nil }
        return result as String
        #endif
    }

    public func scanUpToCharacters(from set: CharacterSet) -> String? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanUpToCharacters(from: set)
        #else
        var result: NSString!
        guard scanner.scanUpToCharacters(from: set, into: &result) else { return nil }
        return result as String
        #endif
    }

    public func scanCharacter() -> Character? {
        #if targetEnvironment(UIKitForMac)
        return scanner.scanCharacter()
        #else
        guard !isAtEnd else { return nil }
        let c = string[currentIndex]
        string.formIndex(after: &currentIndex)
        return c
        #endif
    }
}
