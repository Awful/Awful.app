//  Environment.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
}
