//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

public extension URL {
    /// Creates a URL instance from the provided string.
    init(_ string: StaticString) {
        self.init(string: "\(string)")!
    }
}
