//  Acknowledgements.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Mustache
import UIKit
import WebKit

private let Log = Logger.get()

final class AcknowledgementsViewController: ViewController {
    private var webView: WKWebView { return view as! WKWebView }
    private var backgroundColor: UIColor { return theme["backgroundColor"]! }
    private var textColor: UIColor { return theme["listTextColor"]! }
    
    override init(nibName: String?, bundle: Bundle?) {
        super.init(nibName: nibName, bundle: bundle)
        
        title = "Acknowledgements"
        modalPresentationStyle = .formSheet
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @IBAction @objc private func didTapDone() {
        dismiss(animated: true)
    }
    
    override func loadView() {
        view = WKWebView()
        webView.navigationDelegate = self
        
        // Avoids flash of white when first presented.
        view.isOpaque = false
        view.backgroundColor = UIColor.clear
        
        let context = [
            "backgroundColor": backgroundColor.hexCode,
            "textColor": textColor.hexCode]
        let html: String
        do {
            html = try MustacheTemplate.render(.acknowledgements, value: context)
        }
        catch {
            Log.e("could not render acknowledgements HTML: \(error)")
            html = ""
        }
        
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    override func themeDidChange() {
        super.themeDidChange()
        
        let js = "var s=document.body.style; s.backgroundColor='\(backgroundColor.hexCode)'; s.color='\(textColor.hexCode)'"
        webView.evaluateJavaScript(js, completionHandler: { result, error in
            if let error = error {
                Log.e("error running script `\(js)` in acknowledgements screen: \(error)")
            }
        })
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
}

extension AcknowledgementsViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated {
            UIApplication.shared.openURL(navigationAction.request.url!)
            decisionHandler(.cancel)
        } else {
            decisionHandler(.allow)
        }
    }
}
