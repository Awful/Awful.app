//  main.swift
//
//  Copyright 2018 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import UIKit

private let appDelegateClassName = NSClassFromString("XCTestCase") == nil ? NSStringFromClass(AppDelegate.self) : nil
UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, appDelegateClassName)
