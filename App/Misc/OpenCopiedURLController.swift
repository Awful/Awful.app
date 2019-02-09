//  OpenCopiedURLController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

/// Checks a pasteboard for a Forums URL at appropriate times and offers to open that URL.
final class OpenCopiedURLController {
    private let client: ForumsClient
    private let pasteboard: UIPasteboard
    private let router: (AwfulRoute) -> Void
    private let settings: AwfulSettings
    private let window: UIWindow
    
    init(client: ForumsClient = .shared,
         pasteboard: UIPasteboard = .general,
         settings: AwfulSettings = .shared(),
         window: UIWindow,
         router: @escaping (AwfulRoute) -> Void)
    {
        self.client = client
        self.pasteboard = pasteboard
        self.router = router
        self.settings = settings
        self.window = window
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: UIApplication.shared)
        NotificationCenter.default.addObserver(self, selector: #selector(settingsDidChange), name: .AwfulSettingsDidChange, object: settings)
    }
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        checkPasteboardForInterestingURL()
    }
    
    @objc private func settingsDidChange(_ notification: Notification) {
        if
            let key = notification.userInfo?[AwfulSettingsDidChangeSettingKey] as? String,
            key == AwfulSettingsKeys.clipboardURLEnabled.takeRetainedValue() as String
        {
            checkPasteboardForInterestingURL()
        }
    }
    
    private func checkPasteboardForInterestingURL() {
        guard
            client.isLoggedIn,
            settings.clipboardURLEnabled,
            let url = pasteboard.coercedURL,
            settings.lastOfferedPasteboardURL != url.absoluteString
                || Tweaks.defaultStore.assign(Tweaks.launch.offerToOpenSameCopiedURL),
            let scheme = url.scheme,
            !Bundle.main.urlTypes
                .flatMap({ $0.schemes })
                .any(where: { scheme.caseInsensitive == $0 }),
            let route = try? AwfulRoute(url)
            else { return }
        
        settings.lastOfferedPasteboardURL = url.absoluteString
        
        let alert = UIAlertController(
            title: String(format: LocalizedString("launch-open-copied-url-alert.title"), Bundle.main.localizedName),
            message: url.absoluteString,
            preferredStyle: .alert)
        alert.addCancelActionWithHandler(nil)
        alert.addActionWithTitle(LocalizedString("launch-open-copied-url-alert.open-button"), handler: {
            self.router(route)
        })
        window.rootViewController?.present(alert, animated: true)
    }
}
