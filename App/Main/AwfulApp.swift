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
        // Get the current theme and set status bar style immediately
        let theme = Theme.defaultTheme()
        let statusBarBackground = theme[string: "statusBarBackground"] ?? "dark"
        let shouldUseLightContent = statusBarBackground == "dark"
        
        // Apply status bar style immediately
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                for window in windowScene.windows {
                    if let rootViewController = window.rootViewController {
                        // Wrap the existing root view controller if it's not already wrapped
                        if !(rootViewController is StatusBarStyleViewController) {
                            let statusBarController = StatusBarStyleViewController(wrapping: rootViewController)
                            statusBarController.updateStatusBarStyle(lightContent: shouldUseLightContent)
                            window.rootViewController = statusBarController
                        }
                    }
                }
            }
        }
    }
}
