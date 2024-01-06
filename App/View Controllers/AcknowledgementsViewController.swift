//  AcknowledgementsViewController.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Stencil
import UIKit
import WebKit

private let Log = Logger.get()

final class AcknowledgementsViewController: ViewController {

    init() {
        super.init(nibName: nil, bundle: nil)
        
        title = LocalizedString("acknowledgements.title")
        modalPresentationStyle = .formSheet
    }
    
    private func render() {
        let context = [
            "backgroundColor": backgroundColor.hexCode,
            "textColor": textColor.hexCode]
        let html: String
        do {
            html = try StencilEnvironment.shared.renderTemplate(.acknowledgements, context: context)
        } catch {
            Log.e("could not render acknowledgements HTML: \(error)")
            html = ""
        }
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    private var backgroundColor: UIColor { return theme["backgroundColor"]! }
    private var textColor: UIColor { return theme["listTextColor"]! }
    
    @objc private func didTapDone() {
        dismiss(animated: true)
    }
    
    // MARK: View lifecycle
    
    private lazy var webView: WKWebView = {
        let webView = WKWebView()
        webView.navigationDelegate = self
        
        // Avoids flash of white when first presented.
        webView.backgroundColor = .clear
        webView.isOpaque = false
        
        return webView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.frame = CGRect(origin: .zero, size: view.bounds.size)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView)
        
        render()
    }
    
    override func themeDidChange() {
        super.themeDidChange()

        Task {
            let js = """
                var s = document.body.style;
                s.backgroundColor = "\(backgroundColor.hexCode)";
                s.color = "\(textColor.hexCode)";
                """
            do {
                try await webView.eval(js)
            } catch {
                Log.e("error running script `\(js)` in acknowledgements screen: \(error)")
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if navigationController?.viewControllers.first! == self {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(didTapDone))
        } else {
            navigationItem.rightBarButtonItem = nil
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        webView.scrollView.flashScrollIndicators()
    }
    
    // MARK: Gunk
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AcknowledgementsViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated {
            UIApplication.shared.open(navigationAction.request.url!)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
