/*  ChromeActivity.swift

 A straight port of: ARChromeActivity.m

 Copyright (c) 2012 Alex Robinson

 Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import UIKit

final class ChromeActivity: UIActivity {
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    override var activityImage: UIImage? {
        return UIImage(named: "ARChromeActivity")
    }

    override var activityType: UIActivity.ActivityType? {
        return .init("ChromeActivity")
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        guard UIApplication.shared.canOpenURL(URL(string: "googlechrome-x-callback://")!) else {
            return false
        }

        return firstHTTPURL(in: activityItems) != nil
    }

    override func perform() {
        var components = URLComponents(string: "googlechrome-x-callback://x-callback-url/open/")!
        components.queryItems = [
            .init(name: "url", value: url.absoluteString),
            .init(name: "x-source", value: Bundle.main.localizedName)]
        UIApplication.shared.open(components.url!)
        activityDidFinish(true)
    }
}

private func firstHTTPURL(in activityItems: [Any]) -> URL? {
    return activityItems.lazy
        .compactMap { $0 as? URL }
        .first {
            switch $0.scheme?.caseInsensitive {
            case "http"?, "https"?: return true
            default: return false
            }
    }
}
