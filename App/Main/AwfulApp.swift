//  AwfulApp.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import Smilies
import SwiftUI

@main
struct AwfulApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @SwiftUI.Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootViewControllerRepresentable()
                .ignoresSafeArea()
                .onOpenURL { url in handleURL(url) }
        }
        .onChange(of: scenePhase) { newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    private func handleURL(_ url: URL) {
        guard ForumsClient.shared.isLoggedIn,
              let route = try? AwfulRoute(url)
        else { return }
        appDelegate.open(route: route)
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            SmilieKeyboardSetIsAwfulAppActive(true)
            appDelegate.automaticallyUpdateDarkModeEnabledIfNecessary()
        case .inactive:
            SmilieKeyboardSetIsAwfulAppActive(false)
            appDelegate.updateShortcutItems()
        case .background:
            do {
                try appDelegate.managedObjectContext.save()
            } catch {
                print("Failed to save on background: \(error)")
            }
        @unknown default:
            break
        }
    }
}
