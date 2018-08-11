//  main.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

let appDelegateClassName = NSClassFromString("XCTestCase") == nil ? NSStringFromClass(AppDelegate.self) : nil
let argv = UnsafeMutableRawPointer(CommandLine.unsafeArgv).bindMemory(to: UnsafeMutablePointer<Int8>.self, capacity: Int(CommandLine.argc))
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, appDelegateClassName)
