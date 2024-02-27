//  OpenCopiedURLController.swift
//
//  Copyright 2019 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulSettings
import Combine
import UIKit

/// Checks a pasteboard for a Forums URL at appropriate times and offers to open that URL.
final class OpenCopiedURLController {
    
    private var cancellables: Set<AnyCancellable> = []
    @FoilDefaultStorage(Settings.clipboardURLEnabled) private var checkPasteboardForURL
    private let client: ForumsClient
    @FoilDefaultStorageOptional(Settings.lastOfferedPasteboardURLString) private var lastOfferedPasteboardURLString
    private let pasteboard: UIPasteboard
    private let router: (AwfulRoute) -> Void
    private let window: UIWindow
    
    init(
        client: ForumsClient = .shared,
        pasteboard: UIPasteboard = .general,
        window: UIWindow,
        router: @escaping (AwfulRoute) -> Void)
    {
        self.client = client
        self.pasteboard = pasteboard
        self.router = router
        self.window = window
        

        Publishers.Merge(
            NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification, object: UIApplication.shared).map { _ in },
            $checkPasteboardForURL.dropFirst().map { _ in }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] in self?.checkPasteboardForInterestingURL() }
        .store(in: &cancellables)
    }
    
    private func checkPasteboardForInterestingURL() {
        guard client.isLoggedIn,
              checkPasteboardForURL,
              let url = pasteboard.coercedURL,
              lastOfferedPasteboardURLString != url.absoluteString,
              let scheme = url.scheme,
              !Bundle.main.urlTypes.flatMap({ $0.schemes }).contains(where: { scheme.caseInsensitive == $0 }),
              let route = try? AwfulRoute(url)
        else { return }
        
        lastOfferedPasteboardURLString = url.absoluteString

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
