//  Bundle+.swift
//
//  Copyright 2024 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

// MARK: Info dictionary getters

public extension Bundle {

    /// Seems to be `true` when installed via TestFlight, and `false` when installed via the App Store.
    var containsSandboxReceipt: Bool {
        let receiptPathComponents = appStoreReceiptURL?.pathComponents ?? []
        return receiptPathComponents.contains("sandboxReceipt")
    }

    /// `kCFBundleNameKey`, localized.
    var localizedName: String {
        object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String ?? ""
    }

    /// `CFBundleShortVersionString`
    var shortVersionString: String? {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    /// `CFBundleURLTypes` with some helpful info included.
    var urlTypes: [URLType] {
        let dicts = infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] ?? []
        return dicts.map { URLType($0) }
    }

    /// Structured values from `CFBundleURLTypes`. Returned from `Bundle.urlTypes`.
    struct URLType {
        /// `CFBundleURLName`
        public let name: String?
        /// `CFBundleTypeRole`
        public let role: String?
        /// `CFBundleURLSchemes`
        public let schemes: [String]

        init(_ plist: [String: Any]) {
            name = plist["CFBundleURLName"] as? String
            role = plist["CFBundleTypeRole"] as? String
            schemes = plist["CFBundleURLSchemes"] as? [String] ?? []
        }
    }

    /// `kCFBundleVersionKey`, localized.
    var version: String? {
        object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String
    }
}
