//  ForumsStatusPageViewController.swift
//
//  Copyright 2026 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import AwfulExtensions
import AwfulTheming
import os
import UIKit
@preconcurrency import WebKit

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ForumsStatusPageViewController")

/**
 Shows the page the Forums redirected to while they're down, as it is, so whatever notice they put there reaches the user without the app needing to understand it.

 The page is loaded live rather than from the response: the redirect is refused before any of the status page is downloaded, and the page has its own images and styles anyway.
 */
final class ForumsStatusPageViewController: ViewController {

    private let statusPageURL: URL
    private var completion: (() -> Void)?
    private var isFinishing = false

    private lazy var webView: WKWebView = {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        return webView
    }()

    private let spinner = UIActivityIndicatorView(style: .large)

    /**
     - Parameters:
       - statusPageURL: Where the Forums redirected to.
       - completion: Called exactly once, when the user closes the sheet.
     */
    init(statusPageURL: URL, completion: @escaping () -> Void) {
        self.statusPageURL = statusPageURL
        self.completion = completion
        super.init(nibName: nil, bundle: nil)

        title = String(localized: "Forums Unavailable")
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(didTapReload))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        // If the sheet gets torn down some other way (e.g. the root view controller is swapped out from under it), the requests waiting on us must still get an answer.
        completion?()
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

        load()
    }

    override func themeDidChange() {
        super.themeDidChange()
        spinner.color = theme["listTextColor"]
    }

    private func load() {
        logger.info("loading status page \(self.statusPageURL, privacy: .public)")
        spinner.startAnimating()
        webView.load(URLRequest(url: statusPageURL))
    }

    @objc private func didTapReload() {
        load()
    }

    @objc private func didTapDone() {
        finish()
        dismiss(animated: true)
    }

    private func finish() {
        guard !isFinishing else { return }
        isFinishing = true
        webView.stopLoading()
        let completion = self.completion
        self.completion = nil
        // Answer before the dismissal animation so the waiting requests retry straight away.
        completion?()
    }

    private func showLoadError(_ error: Error) {
        spinner.stopAnimating()
        guard !isFinishing else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled { return }
        logger.error("status page failed to load: \(error)")
        present(UIAlertController(networkError: error), animated: true)
    }
}

extension ForumsStatusPageViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finish()
    }
}

extension ForumsStatusPageViewController: WKNavigationDelegate {
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
