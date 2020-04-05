//  DecodableHelpers.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

@propertyWrapper public struct DefaultEmpty<T: Decodable>: Decodable {
    public var wrappedValue: [T]

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = (try? container.decode([T].self)) ?? []
    }
}
extension DefaultEmpty: Equatable where T: Equatable {}
extension DefaultEmpty: Hashable where T: Hashable {}

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

// MARK: -

@propertyWrapper public struct IntToBool: Decodable {
    public var wrappedValue: Bool?

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            wrappedValue = intValue != 0
        }
    }
}

// MARK: -

@propertyWrapper public struct IntOrString: Decodable {
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
