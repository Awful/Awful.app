//
//  Environment.swift
//  Awful
//
//  Created by Nolan Waite on 2019-02-07.
//  Copyright © 2019 Awful Contributors. All rights reserved.
//

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
