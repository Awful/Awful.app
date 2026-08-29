//  Environment.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

enum Environment {
    static var isDebugBuild: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
    
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }
    
    static var isInstalledViaTestFlight: Bool {
        return !isSimulator && Bundle.main.containsSandboxReceipt
    }

    /// The thread ID of the app's feedback thread ("Awful's Thread"), where the reply composer
    /// offers a Specs button.
    static let feedbackThreadID: String = {
        guard let threadID = Bundle.main.object(forInfoDictionaryKey: "AwfulFeedbackThreadID") as? String else {
            fatalError("missing feedback thread ID; add AwfulFeedbackThreadID to Info.plist")
        }
        return threadID
    }()
}
