//  OpenCopiedURLController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import UIKit

/// Checks a pasteboard for a Forums URL at appropriate times and offers to open that URL.
final class OpenCopiedURLController {
    
    private let client: ForumsClient
    private var observer: NSKeyValueObservation?
    private let pasteboard: UIPasteboard
    private let router: (AwfulRoute) -> Void
    private let window: UIWindow
    
    init(client: ForumsClient = .shared,
         pasteboard: UIPasteboard = .general,
         window: UIWindow,
         router: @escaping (AwfulRoute) -> Void)
    {
        self.client = client
        self.pasteboard = pasteboard
        self.router = router
        self.window = window
        
        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: UIApplication.shared)
        observer = UserDefaults.standard.observeOnMain(\.openCopiedURLAfterBecomingActive) {
            [weak self] defaults, change in
            self?.checkPasteboardForInterestingURL()
        }
    }
    
    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        checkPasteboardForInterestingURL()
    }
    
    private func checkPasteboardForInterestingURL() {
        guard
            client.isLoggedIn,
            UserDefaults.standard.openCopiedURLAfterBecomingActive,
            let url = pasteboard.coercedURL,
            UserDefaults.standard.lastOfferedPasteboardURLString != url.absoluteString,
            let scheme = url.scheme,
            !Bundle.main.urlTypes
                .flatMap({ $0.schemes })
                .contains(where: { scheme.caseInsensitive == $0 }),
            let route = try? AwfulRoute(url)
            else { return }
        
        UserDefaults.standard.lastOfferedPasteboardURLString = url.absoluteString
        
        let alert = UIAlertController(
            title: String(format: LocalizedString("launch-open-copied-url-alert.title"), Bundle.main.localizedName),
            message: url.absoluteString,
            alertActions: [
                    .default(title: LocalizedString("launch-open-copied-url-alert.open-button")) { self.router(route) },
                    .cancel(),
            ]
        )
        window.rootViewController?.present(alert, animated: true)
    }
}
