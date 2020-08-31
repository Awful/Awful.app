//  main.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

// Fix Swift KVO bug SR-6795 (race in setup after initial call to `observe(…)` can cause crash on background thread). Thanks to https://github.com/apple/swift/pull/20103#issuecomment-435558912 et al.
if #available(iOS 13.0, *) {
    // Bug fixed upstream. (Note: iOS 12.2 ships with its own Swift stdlib that is affected by this bug. The app bundles a copy of the Swift stdlib for pre-iOS 12.2, but I don't know if the bundled stdlib includes the fix.)
} else {
    class SR6795Workaround: NSObject {
        @objc dynamic var dummy = 0
    }
    let instance = SR6795Workaround()
    let observer = instance.observe(\.dummy, changeHandler: { _, _ in })
    observer.invalidate()
}


private let appDelegateClassName = NSClassFromString("XCTestCase") == nil ? NSStringFromClass(AppDelegate.self) : nil
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, appDelegateClassName)
