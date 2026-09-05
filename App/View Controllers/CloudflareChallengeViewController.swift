//  CloudflareChallengeViewController.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulCore
import AwfulExtensions
import AwfulTheming
import os
import UIKit
@preconcurrency import WebKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CloudflareChallengeViewController")

/**
 Shows a Cloudflare challenge page in a web view so the user can clear it, then copies the clearance cookies into `HTTPCookieStorage.shared` for `ForumsClient` to use.

 The web view deliberately uses `awfulUserAgent`: Cloudflare binds `cf_clearance` to the User-Agent that solved the challenge, so a clearance earned under Safari's UA would be useless to the app's URLSession.
 */
final class CloudflareChallengeViewController: ViewController {

    private let challenge: CloudflareChallenge
    private let loadURL: URL
    private var completion: ((Bool) -> Void)?
    private var isFinishing = false

    private lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        // A throwaway store: cookies are seeded from and copied back to HTTPCookieStorage.shared explicitly, so nothing lingers between challenges.
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = awfulUserAgent
        webView.navigationDelegate = self

        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        return webView
    }()

    private let spinner = UIActivityIndicatorView(style: .large)

    /**
     - Parameters:
       - challenge: The challenge that was detected.
       - loadURL: What to load in the web view. Cloudflare reloads this URL as a GET once the challenge is solved.
       - completion: Called exactly once, with `true` if the challenge was cleared and the cookies copied, or `false` if the user cancelled.
     */
    init(challenge: CloudflareChallenge, loadURL: URL, completion: @escaping (Bool) -> Void) {
        self.challenge = challenge
        self.loadURL = loadURL
        self.completion = completion
        super.init(nibName: nil, bundle: nil)

        title = String(localized: "Verify Your Browser")
        isModalInPresentation = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(didTapCancel))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(didTapReload))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // If the sheet gets torn down some other way (e.g. the root view controller is swapped out from under it), the requests waiting on us must still get an answer.
        completion?(false)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        webView.frame = view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)

        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
        ])

        Task {
            await seedCookies()
            load()
        }
    }

    override func themeDidChange() {
        super.themeDidChange()
        spinner.color = theme["listTextColor"]
    }

    // MARK: Loading

    /// Copies the app's Forums cookies into the web view so the challenge is solved for the same session (`bbuserid`, `__cf_bm`, …) that `ForumsClient` will retry with.
    private func seedCookies() async {
        let store = webView.configuration.websiteDataStore.httpCookieStore
        for cookie in HTTPCookieStorage.shared.cookies(for: loadURL) ?? [] {
            await store.setCookie(cookie)
        }
    }

    private func load() {
        logger.info("loading challenge page \(self.loadURL, privacy: .public) (challenged: \(self.challenge.requestMethod) \(self.challenge.url, privacy: .public), ray \(self.challenge.rayID ?? "-", privacy: .public))")
        spinner.startAnimating()

#if DEBUG
        if challenge.rayID == FixtureURLProtocol.simulatedCloudflareRayID {
            // The simulated challenge only exists in URLSession, so the real page would load here and clear the sheet at once. Show a stand-in that waits for a tap instead.
            webView.loadHTMLString(Self.simulatedChallengePage(continuingTo: loadURL), baseURL: loadURL)
            return
        }
#endif

        webView.load(URLRequest(url: loadURL))
    }

#if DEBUG
    private static func simulatedChallengePage(continuingTo url: URL) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        body { font-family: -apple-system, sans-serif; margin: 0; padding: 48px 24px; color: #313131; background: #fff; }
        @media (prefers-color-scheme: dark) { body { color: #d9d9d9; background: #222; } }
        h1 { font-size: 22px; margin: 0 0 8px; }
        p { margin: 0 0 24px; line-height: 1.4; }
        a { display: inline-block; padding: 12px 20px; border-radius: 8px; background: #f38020; color: #fff; text-decoration: none; font-weight: 600; }
        small { display: block; margin-top: 32px; opacity: 0.6; }
        </style>
        </head>
        <body>
        <h1>forums.somethingawful.com</h1>
        <p>Simulated Cloudflare challenge. A real one shows Cloudflare's verification widget here.</p>
        <a href="\(url.absoluteString)">Verify you are human</a>
        <small>DEBUG build · FixtureURLProtocol.simulatedCloudflareChallenge</small>
        </body>
        </html>
        """
    }
#endif

    @objc private func didTapReload() {
        load()
    }

    @objc private func didTapCancel() {
        finish(cleared: false)
    }

    /// Moves Cloudflare's cookies from the web view into the shared storage that `ForumsClient`'s sessions read.
    private func copyClearanceCookies() async {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        let relevant = cookies.filter { CloudflareChallenge.isCloudflareCookie($0) && $0.domain.lowercased().hasSuffix("somethingawful.com") }
        for cookie in relevant {
            HTTPCookieStorage.shared.setCookie(cookie)
        }
        logger.info("copied Cloudflare cookies to shared storage: \(relevant.map(\.name).joined(separator: ","), privacy: .public)")
    }

    private func finish(cleared: Bool) {
        guard !isFinishing else { return }
        isFinishing = true
        webView.stopLoading()
        let completion = self.completion
        self.completion = nil
#if DEBUG
        if cleared, challenge.rayID == FixtureURLProtocol.simulatedCloudflareRayID {
            FixtureURLProtocol.simulatedCloudflareChallengeWasVerified = true
        }
#endif
        // Answer before the dismissal animation so the waiting requests retry straight away, and so the answer doesn't depend on UIKit calling the dismissal completion.
        completion?(cleared)
        dismiss(animated: true)
    }

    private func showLoadError(_ error: Error) {
        spinner.stopAnimating()
        // Cancelled loads (the reload button mid-load, or the navigation we cancel once the challenge clears) aren't worth an alert.
        guard !isFinishing else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
        logger.error("challenge page failed to load: \(error)")
        present(UIAlertController(networkError: error), animated: true)
    }
}

extension CloudflareChallengeViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        guard navigationResponse.isForMainFrame,
              let http = navigationResponse.response as? HTTPURLResponse,
              !isFinishing
        else { return decisionHandler(.allow) }

        let isChallenge = CloudflareChallenge.isChallengeResponse(http)
        logger.debug("main-frame response \(http.statusCode) for \(http.url?.absoluteString ?? "?", privacy: .public) challenge=\(isChallenge)")
        guard !isChallenge else { return decisionHandler(.allow) }

        // Cloudflare let the page through, which is all we wanted; there's no point rendering it. The clearance cookie was set by Cloudflare's own verification request before this reload, so it's already in the store.
        decisionHandler(.cancel)
        Task {
            await copyClearanceCookies()
            finish(cleared: true)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        showLoadError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        showLoadError(error)
    }
}
