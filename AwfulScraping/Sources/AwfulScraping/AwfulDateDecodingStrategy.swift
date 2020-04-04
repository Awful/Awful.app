//  AwfulDateDecodingStrategy.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

public extension JSONDecoder.DateDecodingStrategy {

    /// Decodes dates as the number of seconds since midnight Jan 1, 1970 in the America/Chicago time zone, which seems to be how the Something Awful Forums servers serialize dates to JSON.
    static var awful: Self {
        let cal = Calendar(identifier: .gregorian)
        let central = TimeZone(identifier: "America/Chicago")!
        let saEpoch = cal.date(from: .init(timeZone: central, year: 1970, month: 1, day: 1, hour: 0, minute: 0, second: 0))!
        return .custom { decoder in
            let container = try decoder.singleValueContainer()
            let secondsSinceSAEpoch = try container.decode(TimeInterval.self)
            return Date(timeInterval: secondsSinceSAEpoch, since: saEpoch)
        }
    }
}
