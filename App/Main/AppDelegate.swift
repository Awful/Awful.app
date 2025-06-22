//  AppDelegate.swift
//
//  Copyright 2016 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import AwfulTheming
import AVFoundation
import Combine
import CoreData
import os
import SwiftUI
import UIKit
import WebKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "AppDelegate")

extension Notification.Name {
    static let didRemotelyLogOut = Notification.Name("AwfulDidRemotelyLogOut")
}

class AppDelegate: UIResponder, UIApplicationDelegate {

    private(set) static var instance: AppDelegate!

    private var cancellables: Set<AnyCancellable> = []
    private var dataStore: DataStore!
    @FoilDefaultStorage(Settings.autoDarkTheme) private var automaticDarkTheme
    @FoilDefaultStorage(Settings.darkMode) private var darkMode
    @FoilDefaultStorage(Settings.defaultDarkThemeName) private var defaultDarkTheme
    @FoilDefaultStorage(Settings.defaultLightThemeName) private var defaultLightTheme
    private var announcementListRefresher: AnnouncementListRefresher?
    private var inboxRefresher: PrivateMessageInboxRefresher?
    var managedObjectContext: NSManagedObjectContext { return dataStore.mainManagedObjectContext }
    @FoilDefaultStorage(Settings.showAvatars) private var showAvatars
    @FoilDefaultStorage(Settings.enableCustomTitlePostLayout) private var showCustomTitles

    // MARK: UIApplicationDelegate

    func application(
        _ application: UIApplication,
        willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        AppDelegate.instance = self

        UserDefaults.standard.register(defaults: Theme.forumSpecificDefaults)

        SettingsMigration.migrate(.standard)

        do {
            let storeURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("Awful", isDirectory: true)
            dataStore = .init(storeDirectoryURL: storeURL)
        } catch {
            fatalError("could not create data store: \(error)")
        }

        ForumsClient.shared.managedObjectContext = dataStore.mainManagedObjectContext
        ForumsClient.shared.baseURL = URL(string: "https://forums.somethingawful.com")!
        ForumsClient.shared.didRemotelyLogOut = {
            self.logOut()
        }

        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "AwfulCache")

        configureAudioSession()
        configureRefreshers()
        
        return true
    }

    func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool {
        return false
    }

    func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool {
        return false
    }

    func application(
        _ application: UIApplication,
        viewControllerWithRestorationIdentifierPath identifierComponents: [String],
        coder: NSCoder
    ) -> UIViewController? {
        return nil
    }

    @objc private func forumSpecificThemeDidChange(_ notification: Notification) {
        // NOP
    }
    
    @objc private func preferredContentSizeDidChange(_ notification: Notification) {
        // NOP
    }

    private func automaticallyUpdateDarkModeEnabledIfNecessary() {
        // NOP
    }

    private func showSnapshotDuringThemeDidChange() {
        // NOP
    }
    
    private func setShowAvatarsSetting() {
        // NOP
    }

    func logOut() {
        // Clear all cookies to log out
        URLSession.shared.configuration.httpCookieStorage?.removeCookies(since: .distantPast)
        
        // Clear the data store
        dataStore.deleteStoreAndReset()

        NotificationCenter.default.post(name: .didRemotelyLogOut, object: nil)
    }
    
    func emptyCache() {
        URLCache.shared.removeAllCachedResponses()
    }

    /// Temporary shim: allow existing UIKit controllers to request routing without directly depending on SwiftUI.
    /// Posts a notification that higher-level coordinators can observe and handle.
    func open(route: AwfulRoute) {
        NotificationCenter.default.post(name: Notification.Name("AwfulRoute"), object: route)
    }
}

private extension AppDelegate {
    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: .default)
        } catch {
            logger.debug("error setting audio session category: \\(error)")
        }
    }

    func configureRefreshers() {
        announcementListRefresher = AnnouncementListRefresher(client: ForumsClient.shared, minder: RefreshMinder.sharedMinder)
        inboxRefresher = PrivateMessageInboxRefresher(client: ForumsClient.shared, minder: RefreshMinder.sharedMinder)
        PostsViewExternalStylesheetLoader.shared.refreshIfNecessary()

        do {
            NotificationCenter.default.addObserver(self, selector: #selector(forumSpecificThemeDidChange), name: Theme.themeForForumDidChangeNotification, object: Theme.self)
            NotificationCenter.default.addObserver(self, selector: #selector(preferredContentSizeDidChange), name: UIContentSizeCategory.didChangeNotification, object: nil)
        }

        do {
            $automaticDarkTheme
                .dropFirst()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.automaticallyUpdateDarkModeEnabledIfNecessary() }
                .store(in: &cancellables)

            $darkMode
                .dropFirst()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.showSnapshotDuringThemeDidChange() }
                .store(in: &cancellables)

            let darkDefaultChange = $defaultDarkTheme
                .dropFirst()
                .filter { [weak self] _ in self?.darkMode == true }
            let lightDefaultChange = $defaultLightTheme
                .dropFirst()
                .filter { [weak self] _ in self?.darkMode == false }
            Publishers.Merge(darkDefaultChange, lightDefaultChange)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.showSnapshotDuringThemeDidChange() }
                .store(in: &cancellables)

            $showCustomTitles
                .dropFirst()
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.setShowAvatarsSetting() }
                .store(in: &cancellables)
        }
    }
}
