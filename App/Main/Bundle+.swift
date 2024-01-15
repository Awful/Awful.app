//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension Bundle {
    private class Sentinel {}
    static var module: Self { self.init(for: Sentinel.self) }
}
