//  NSURL-OpensInBrowser.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

extension URL {
    /// Returns true if this URL would normally open in Safari, or false otherwise.
    var opensInBrowser: Bool {
        switch scheme.map(CaseInsensitive.init) {
        case "http"?, "https"?, "ftp"?:
            break
        default:
            return false
        }
        
        guard let host = host else { return true }
        switch CaseInsensitive(host) {
        case "itunes.apple.com", "phobos.apple.com":
            return false
        default:
            return true
        }
    }
}
