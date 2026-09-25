//  DecodableHelpers.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation
import HTMLReader

@propertyWrapper public struct DecodingEntities: Decodable, Sendable {
    public var wrappedValue: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try (try? container.decode(String.self)) ?? String(container.decode(Int.self))
        wrappedValue = (rawString as NSString).html_stringByUnescapingHTML
    }
}

// MARK: -

@propertyWrapper public struct DefaultEmpty<T: Decodable>: Decodable {
    public var wrappedValue: [T]

    /// How many elements were too malformed to decode, available as `$property`.
    public private(set) var projectedValue = 0

    public init(from decoder: Decoder) throws {
        guard var container = try? decoder.unkeyedContainer() else {
            wrappedValue = []
            return
        }

        // Decode element by element so one malformed entry (say, a subforum whose description is a number) costs only itself, not every sibling alongside it.
        var elements: [T] = []
        while !container.isAtEnd {
            if (try? container.decodeNil()) == true { continue }
            if let element = try? container.decode(T.self) {
                elements.append(element)
            } else if (try? container.decode(Skipped.self)) != nil {
                projectedValue += 1
            } else {
                break
            }
        }
        wrappedValue = elements
    }

    /// Decodes anything without looking at it, so a failed element can be stepped over.
    private struct Skipped: Decodable {
        init(from decoder: Decoder) {}
    }

    fileprivate init(missing: Void) {
        wrappedValue = []
    }
}

extension KeyedDecodingContainer {
    /// A missing key is as good as an empty array.
    public func decode<T>(_ type: DefaultEmpty<T>.Type, forKey key: Key) throws -> DefaultEmpty<T> {
        try decodeIfPresent(type, forKey: key) ?? DefaultEmpty(missing: ())
    }
}
extension DefaultEmpty: Equatable where T: Equatable {}
extension DefaultEmpty: Hashable where T: Hashable {}
extension DefaultEmpty: Sendable where T: Sendable {}

// MARK: -

@propertyWrapper public struct EmptyStringNil<T: Decodable>: Decodable {
    public var wrappedValue: T?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { return }
        do {
            wrappedValue = try container.decode(T.self)
            if let string = wrappedValue as? String, string.isEmpty {
                wrappedValue = nil
            }
        } catch {
            if let string = (try? container.decode(String.self)), string.isEmpty {
                wrappedValue = nil
            } else {
                throw error
            }
        }
    }
}

extension EmptyStringNil: Sendable where T: Sendable {}

// MARK: -

@propertyWrapper public struct IntToBool: Decodable, Sendable {
    public var wrappedValue: Bool?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            wrappedValue = intValue != 0
        }
    }

    fileprivate init(_ value: Bool?) {
        wrappedValue = value
    }
}

extension KeyedDecodingContainer {
    /// A missing key is as good as `null` for an optional value.
    public func decode(_ type: IntToBool.Type, forKey key: Key) throws -> IntToBool {
        try decodeIfPresent(type, forKey: key) ?? IntToBool(nil)
    }
}

// MARK: -

/// A `Bool` that also accepts `0` or `1`.
@propertyWrapper public struct BoolOrInt: Decodable, Sendable {
    public var wrappedValue: Bool

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolValue = try? container.decode(Bool.self) {
            wrappedValue = boolValue
        } else {
            wrappedValue = try container.decode(Int.self) != 0
        }
    }
}

// MARK: -

/// An optional value that's `nil` when it's missing, `null`, or not something `T` can decode, so one odd value can't sink the whole response.
@propertyWrapper public struct Lenient<T: Decodable>: Decodable {
    public var wrappedValue: T?

    public init(from decoder: Decoder) throws {
        wrappedValue = try? decoder.singleValueContainer().decode(T.self)
    }

    fileprivate init(_ value: T?) {
        wrappedValue = value
    }
}

extension Lenient: Sendable where T: Sendable {}

extension KeyedDecodingContainer {
    public func decode<T>(_ type: Lenient<T>.Type, forKey key: Key) throws -> Lenient<T> {
        try decodeIfPresent(type, forKey: key) ?? Lenient(nil)
    }
}

// MARK: -

@propertyWrapper public struct IntOrString: Decodable, Sendable {
    public var wrappedValue: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            wrappedValue = stringValue
        } else {
            wrappedValue = try String(container.decode(Int.self))
        }
    }
}

@propertyWrapper public struct CoerceIntToString: Decodable, Sendable {
    public var wrappedValue: String?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            wrappedValue = stringValue
        } else {
            wrappedValue = try? String(container.decode(Int.self))
        }
    }

    fileprivate init(_ value: String?) {
        wrappedValue = value
    }
}

extension KeyedDecodingContainer {
    /// A missing key is as good as `null` for an optional value.
    public func decode(_ type: CoerceIntToString.Type, forKey key: Key) throws -> CoerceIntToString {
        try decodeIfPresent(type, forKey: key) ?? CoerceIntToString(nil)
    }
}
