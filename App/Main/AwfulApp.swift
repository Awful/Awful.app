//  AwfulApp.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulSettings
import AwfulTheming
import SwiftUI

@main
struct AwfulApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    // Set initial status bar style early
                    setInitialStatusBarStyle()
                }
        }
    }
    
    private func setInitialStatusBarStyle() {
        // Status bar style is now handled by SwiftUI's preferredColorScheme
        // No need for initial UIKit setup
    }
}
